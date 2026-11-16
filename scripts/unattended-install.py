#!/usr/bin/env python3
"""Run this repository's install stages without stdin or a controlling terminal."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile


def run_stage(repo, stage, env, log=None):
    print(f"==> {stage}", flush=True)
    if log:
        log.write(f"==> {stage}\n".encode())
    child = subprocess.Popen(
        ["bash", str(repo / "scripts/install-stage.sh"), stage], cwd=repo,
        stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        start_new_session=True, env=env,
    )
    try:
        while True:
            block = child.stdout.read1(65536)
            if not block:
                break
            if log:
                log.write(block)
                log.flush()
            try:
                sys.stdout.buffer.write(block)
                sys.stdout.buffer.flush()
            except BrokenPipeError:
                pass
        result = child.wait()
        return result if result >= 0 else 128 - result
    except BaseException:
        try:
            os.killpg(child.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            child.wait(timeout=5)
        except subprocess.TimeoutExpired:
            os.killpg(child.pid, signal.SIGKILL)
            child.wait()
        raise
    finally:
        child.stdout.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--non-interactive', action='store_true', help='Run the unattended installation')
    parser.add_argument('--check', action='store_true', help='Read-only prerequisite check; no log files')
    parser.add_argument('--log-dir', type=Path, help='Parent directory for private per-run logs')
    args = parser.parse_args()
    if not args.non_interactive and not args.check:
        parser.error('specify --non-interactive or --check')
    if args.check and args.log_dir:
        parser.error('--check does not write logs')
    repo = Path(__file__).resolve().parents[1]
    name = (repo / 'scripts/install-name').read_text().strip()
    env = os.environ.copy()
    env.update(DOTFILES_NONINTERACTIVE='1', NONINTERACTIVE='1',
               GIT_TERMINAL_PROMPT='0', GCM_INTERACTIVE='Never',
               GIT_ASKPASS='/usr/bin/false', SSH_ASKPASS='/usr/bin/false',
               SSH_ASKPASS_REQUIRE='never', SUDO_ASKPASS='/usr/bin/false',
               GIT_SSH_COMMAND='ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=15')
    if args.check:
        return run_stage(repo, 'preflight', env)
    os.umask(0o077)
    state = Path(env.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))) / name
    state.mkdir(parents=True, exist_ok=True)
    with (state / 'install.lock').open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            print(f'{name}: another installer is running', file=sys.stderr)
            return 75
        logs = args.log_dir or state / 'install-logs'
        logs.mkdir(parents=True, exist_ok=True)
        run = Path(tempfile.mkdtemp(prefix='run-', dir=logs))
        print(f'Install log: {run / "output.log"}', flush=True)
        records = []
        result = 1
        stage = 'preflight'
        with (run / 'output.log').open('wb') as log:
            try:
                for stage in ('preflight', 'install', 'verify'):
                    result = run_stage(repo, stage, env, log)
                    records.append({'stage': stage, 'exit_code': result})
                    if result:
                        break
            except KeyboardInterrupt:
                result = 130
                records.append({'stage': stage, 'exit_code': result})
            except InterruptedError:
                result = 143
                records.append({'stage': stage, 'exit_code': result})
            except (OSError, ValueError) as error:
                result = 1
                records.append({'stage': stage, 'exit_code': result})
                message = f'Installer error during {stage}: {error}\n'
                log.write(message.encode())
                print(message, end='', file=sys.stderr)
            finally:
                (run / 'result.json').write_text(json.dumps({
                    'repository': name, 'exit_code': result, 'stages': records,
                }, indent=2) + '\n')
        print(f'{name}: {"complete" if result == 0 else "incomplete"} (exit {result}); log: {run / "output.log"}')
        return result


def interrupted(_signum, _frame):
    raise InterruptedError('Installation interrupted')


if __name__ == '__main__':
    signal.signal(signal.SIGTERM, interrupted)
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
    except InterruptedError:
        sys.exit(143)
    except (OSError, ValueError) as error:
        print(f'Installer error: {error}', file=sys.stderr)
        sys.exit(1)
