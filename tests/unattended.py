"""Exercise the real runner against isolated stages; never change HOME."""
import fcntl
import importlib.util
import json
import os
from pathlib import Path
import pty
import select
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch


REPO = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('runner', REPO / 'scripts/unattended-install.py')
RUNNER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RUNNER)


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / 'checkout with spaces'
        (self.repo / 'scripts').mkdir(parents=True)
        shutil.copy2(REPO / 'scripts/unattended-install.py', self.repo / 'scripts/unattended-install.py')
        (self.repo / 'scripts/install-name').write_text('fixture\n')
        self.stage = self.repo / 'scripts/install-stage.sh'
        self.stage.write_text('''#!/usr/bin/env bash
set -euo pipefail
printf '%s\\n' "$1" >> "$TRACE"
printf 'stdout %s\\n' "$1"
printf 'stderr %s\\n' "$1" >&2
[[ ! -t 0 && ! -t 1 && ! -t 2 ]]
if read -r answer; then exit 90; fi
# A descendant must not be able to reopen the caller's terminal.
if (exec 3</dev/tty) 2>/dev/null; then exit 91; fi
[[ "$GIT_TERMINAL_PROMPT" == 0 && "$SUDO_ASKPASS" == /usr/bin/false ]]
if [[ "${WAIT_STAGE:-}" == "$1" ]]; then sleep 30; fi
if [[ "${FAIL_STAGE:-}" == "$1" ]]; then exit "${FAIL_CODE:-42}"; fi
''')
        self.env = dict(os.environ, XDG_STATE_HOME=str(self.root / 'state'), TRACE=str(self.root / 'trace'))
        # Avoid test behavior depending on the caller's interactive environment.
        self.env.pop('FAIL_STAGE', None)
        self.env.pop('WAIT_STAGE', None)
        self.command = [sys.executable, '-B', str(self.repo / 'scripts/unattended-install.py')]

    def invoke(self, *args):
        return subprocess.run(self.command + list(args), env=self.env, capture_output=True, timeout=10)

    def records(self):
        paths = list((self.root / 'state/fixture/install-logs').glob('*/result.json'))
        self.assertEqual(len(paths), 1)
        return paths[0], json.loads(paths[0].read_text())

    def test_success_logs_and_permissions(self):
        proc = self.invoke('--non-interactive')
        self.assertEqual(proc.returncode, 0, proc.stderr + proc.stdout)
        self.assertEqual((self.root / 'trace').read_text().splitlines(), ['preflight', 'install', 'verify'])
        path, result = self.records()
        self.assertEqual(result['exit_code'], 0)
        self.assertEqual(path.parent.stat().st_mode & 0o777, 0o700)
        for file in (path, path.with_name('output.log')):
            self.assertEqual(file.stat().st_mode & 0o777, 0o600)
        self.assertIn('stderr install', path.with_name('output.log').read_text())
        self.assertFalse((self.repo / 'install-logs').exists())

    def test_failures_stop_dependent_stages_and_keep_exit_status(self):
        for index, stage in enumerate(('preflight', 'install', 'verify')):
            with self.subTest(stage=stage):
                self.env.update(FAIL_STAGE=stage, XDG_STATE_HOME=str(self.root / stage))
                (self.root / 'trace').unlink(missing_ok=True)
                proc = self.invoke('--non-interactive')
                self.assertEqual(proc.returncode, 42, proc.stderr + proc.stdout)
                self.assertEqual(len((self.root / 'trace').read_text().splitlines()), index + 1)
                result = next((self.root / stage).glob('fixture/install-logs/*/result.json'))
                self.assertEqual(json.loads(result.read_text())['exit_code'], 42)

    def test_check_only_and_help_do_not_create_state(self):
        for args in (['--help'], ['--check']):
            self.assertEqual(self.invoke(*args).returncode, 0)
            self.assertFalse((self.root / 'state').exists())
        self.assertEqual((self.root / 'trace').read_text(), 'preflight\n')

    def test_invalid_arguments_cannot_install(self):
        for args in ([], ['--typo'], ['--check', '--log-dir', str(self.root)]):
            self.assertEqual(self.invoke(*args).returncode, 2)
        self.assertFalse((self.root / 'trace').exists())

    def test_stages_detach_from_an_interactive_callers_terminal(self):
        pid, terminal = pty.fork()
        if pid == 0:
            os.execve(sys.executable, self.command + ['--non-interactive'], self.env)
        output = b''
        try:
            deadline = time.monotonic() + 8
            while time.monotonic() < deadline:
                if select.select([terminal], [], [], .1)[0]:
                    try:
                        chunk = os.read(terminal, 65536)
                    except OSError:
                        break
                    if not chunk:
                        break
                    output += chunk
            else:
                os.kill(pid, signal.SIGKILL)
                self.fail('installer waited on a terminal')
        finally:
            os.close(terminal)
            _, status = os.waitpid(pid, 0)
        self.assertEqual(os.waitstatus_to_exitcode(status), 0, output)

    def test_custom_logs(self):
        self.assertEqual(self.invoke('--non-interactive', '--log-dir', str(self.root / 'logs')).returncode, 0)
        self.assertEqual(len(list((self.root / 'logs').glob('*/result.json'))), 1)

    def test_concurrent_installation_is_rejected(self):
        state = self.root / 'state/fixture'
        state.mkdir(parents=True)
        with (state / 'install.lock').open('a') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.assertEqual(self.invoke('--non-interactive').returncode, 75)
        self.assertFalse((self.root / 'trace').exists())

    def test_interrupt_writes_failure_and_stops_children(self):
        self.env['WAIT_STAGE'] = 'install'
        proc = subprocess.Popen(self.command + ['--non-interactive'], env=self.env,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            deadline = time.monotonic() + 5
            while time.monotonic() < deadline:
                trace = self.root / 'trace'
                if trace.exists() and 'install' in trace.read_text():
                    break
                time.sleep(.02)
            else:
                self.fail('installation never started')
            proc.send_signal(signal.SIGTERM)
            stdout, stderr = proc.communicate(timeout=8)
            self.assertEqual(proc.returncode, 143, stdout + stderr)
            self.assertEqual(self.records()[1]['exit_code'], 143)
            self.assertNotIn('verify', trace.read_text())
        finally:
            if proc.poll() is None:
                proc.kill()
                proc.communicate()

    def test_launch_error_cannot_record_success(self):
        # A successful preflight followed by a failed process launch must not
        # leave a success receipt from the preceding stage.
        with patch.object(RUNNER, '__file__', str(self.repo / 'scripts/unattended-install.py')), \
             patch.dict(os.environ, self.env), \
             patch.object(sys, 'argv', ['installer', '--non-interactive']), \
             patch.object(RUNNER, 'run_stage', side_effect=[0, OSError('cannot launch')]):
            original_umask = os.umask(0o077)
            try:
                self.assertEqual(RUNNER.main(), 1)
            finally:
                os.umask(original_umask)
        self.assertEqual(self.records()[1]['exit_code'], 1)


if __name__ == '__main__':
    unittest.main()
