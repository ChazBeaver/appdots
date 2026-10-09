#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

APPDOTS_TEST_REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
APPDOTS_TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$APPDOTS_TEST_ROOT"' EXIT
export APPDOTS_TEST_REPO APPDOTS_TEST_ROOT
# A shell function takes precedence over the helper's fallback PATH without
# changing HOME or contacting the user's running Herdr server.
herdr() { python3 "$APPDOTS_TEST_ROOT/herdr.py" "$@"; }
export -f herdr
cat > "$APPDOTS_TEST_ROOT/herdr.py" <<'PY'
import json
import os
from pathlib import Path
import sys

root = Path(os.environ['APPDOTS_TEST_ROOT'])
state_file = root / 'state.json'
state = json.loads(state_file.read_text())
args = sys.argv[1:]
state['calls'].append(args)
def save():
    state_file.write_text(json.dumps(state))
def option(name):
    return args[args.index(name) + 1]
save()
if os.environ.get('APPDOTS_TEST_HERDR_FAIL') == ' '.join(args[:2]):
    sys.exit(1)
if args[:2] in (['worktree', 'create'], ['worktree', 'open'], ['workspace', 'create']):
    result = {'workspace': {'workspace_id': 'ws-target'}}
    if not os.environ.get('APPDOTS_TEST_HERDR_BAD_RESPONSE'):
        result['worktree'] = {'path': str(root / 'actual worktree')}
elif args[:2] == ['tab', 'list']:
    result = {'tabs': state['tabs']}
elif args[:2] == ['tab', 'rename']:
    for tab in state['tabs']:
        if tab['tab_id'] == args[2]:
            tab['label'] = args[3]
    result = {}
elif args[:2] == ['tab', 'create']:
    state['tabs'].append({'tab_id': f"tab-{len(state['tabs'])+1}",
                          'number': len(state['tabs']) + 1,
                          'label': option('--label'), 'cwd': option('--cwd')})
    result = {}
elif args[:2] == ['workspace', 'focus']:
    result = {}
else:
    raise SystemExit(f'Unexpected Herdr call: {args}')
save()
print(json.dumps({'result': result}))
PY

python3 - <<'PY'
import json
import os
from pathlib import Path
import subprocess
import tomllib

root = Path(os.environ['APPDOTS_TEST_ROOT'])
repo = Path(os.environ['APPDOTS_TEST_REPO'])
checkout = root / 'source checkout'
subprocess.run(['git', 'init', '-q', str(checkout)], check=True)
env = dict(os.environ, HERDR_ENV='1', HERDR_ACTIVE_PANE_CWD=str(checkout))
script = repo / 'bin/shared/herdr-workspace.sh'
state_file = root / 'state.json'
def reset(labels=('1',)):
    state_file.write_text(json.dumps({'calls': [], 'tabs': [
        {'tab_id': f'tab-{i}', 'number': i, 'label': label}
        for i, label in enumerate(labels, 1)]}))
def state():
    return json.loads(state_file.read_text())
def run(*args, success=True, extra=None):
    result = subprocess.run(['bash', str(script), *args], env=env | (extra or {}),
                            stdin=subprocess.DEVNULL, capture_output=True, text=True)
    assert (result.returncode == 0) == success, (args, result.stdout, result.stderr)
    return state()

reset()
s = run('worktree', 'feature/test', 'main')
assert [t['label'] for t in s['tabs']] == ['chat', 'repo']
assert s['tabs'][1]['cwd'] == str(root / 'actual worktree'), 'repo tab used source checkout'
assert s['calls'][0] == ['worktree', 'create', '--cwd', str(checkout),
                          '--branch', 'feature/test', '--no-focus', '--base', 'main']
assert s['calls'][-1] == ['workspace', 'focus', 'ws-target']
s = run('open', str(root / 'actual worktree'))
assert [t['label'] for t in s['tabs']] == ['chat', 'repo'], 'reopen duplicated tabs'
assert ['worktree', 'open', '--cwd', str(checkout), '--path',
        str(root / 'actual worktree'), '--no-focus'] in s['calls']

reset(('editor',))
s = run('open', str(root / 'actual worktree'))
assert [t['label'] for t in s['tabs']] == ['editor', 'chat', 'repo'], 'custom tab renamed or standard tab missing'
reset(('1', 'chat'))
s = run('layout', 'ws-target')
assert [t['label'] for t in s['tabs']] == ['1', 'chat', 'repo'], 'existing chat duplicated'
reset()
s = run('new', 'ordinary workspace')
assert [t['label'] for t in s['tabs']] == ['chat', 'repo'], 'ordinary workspace layout regressed'
assert s['tabs'][1]['cwd'] == str(checkout)
reset()
s = run('worktree', 'feature/default')
assert '--base' not in s['calls'][0], 'default base should be left to Herdr'

for args, extra in [
    (('worktree', 'feature/test'), {'HERDR_ENV': ''}),
    (('worktree', 'bad..branch'), {}),
    (('worktree',), {}),
    (('open',), {}),
    (('worktree', 'feature/test'), {'APPDOTS_TEST_HERDR_FAIL': 'worktree create'}),
    (('worktree', 'feature/test'), {'APPDOTS_TEST_HERDR_BAD_RESPONSE': '1'}),
    (('worktree', 'feature/test'), {'APPDOTS_TEST_HERDR_FAIL': 'tab create'}),
]:
    reset()
    s = run(*args, success=False, extra=extra)
    assert not any(c[:2] == ['workspace', 'focus'] for c in s['calls']), 'focused after setup failure'

for platform in ('linux', 'macos'):
    config = tomllib.loads((repo / f'active/{platform}/.config/herdr/config.toml').read_text())
    assert config['keys']['new_worktree'] == ''
    assert config['keys']['remove_worktree'] == 'prefix+shift+t'
    entries = [c for c in config['keys']['command'] if c['key'] == 'prefix+ctrl+t']
    assert len(entries) == 1 and entries[0]['command'].endswith('herdr-workspace worktree')
print('PASS: Herdr worktree layout, checkout paths, idempotence, custom tabs, failure handling, and both platform bindings')
PY
