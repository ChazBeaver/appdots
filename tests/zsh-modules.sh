#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

APPDOTS_TEST_REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export APPDOTS_TEST_REPO

# Child shells get disposable home directories; never source the user's
# registry, plugins, or local environment as part of a fixture.
python3 - <<'PY'
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

repo = Path(os.environ['APPDOTS_TEST_REPO'])
zsh = shutil.which('zsh')
assert zsh, 'zsh is required'
startup = repo / 'active/shared/HOME/zsh/.zshrc'
modules = startup.parent / 'zsh_modules'

check = r'''
fail() { print -u2 -r -- "$*"; exit 1; }
uname() { print -r -- "$APPDOTS_TEST_OS"; }
# Non-interactive loading skips the Linux interactive plugin. Homebrew's
# optional plugin paths point at an empty fixture directory.
source "$APPDOTS_TEST_STARTUP"
set -eu
setopt pipefail

shared_functions=(fn home cx reporoot edit-zshrc mkcd y printcolors fda fe fcd fh
  home-pull home-status home-sync home-doctor grc grr grp grs gsp gmm gpp gpl
  gfn gdf gbc gbi gmo gmi gbu gbo gbl gbs gbv gbp gbr gbd)
if [[ "$APPDOTS_TEST_OS" == Linux ]]; then
  platform_functions=(cam notes work open)
  (( ! ${+functions[edit-ghostty]} )) || fail 'macOS function leaked onto Linux'
else
  platform_functions=(notes edit-ghostty)
  for name in cam work; do
    (( ! ${+functions[$name]} )) || fail "Linux function leaked onto macOS: $name"
  done
fi

verify() {
  local name
  (( APPDOTS_TEST_ENV_LOADS == $1 )) || fail 'Registry loaded more than once per startup'
  (( APPDOTS_TEST_PROMPT_LOADS == $1 )) || fail 'Prompt module was not loaded once'
  (( APPDOTS_TEST_LOCAL_LOADS == $1 )) || fail 'Local environment was not loaded once'
  (( ${#_AD_FN_GROUP} == ${#shared_functions} + ${#platform_functions} )) || fail 'Unexpected palette entries'
  for name in "${shared_functions[@]}" "${platform_functions[@]}"; do
    _ad_fn_owned "$name" || fail "Function missing from palette: $name"
  done
  [[ "${aliases[hp]}" == home-pull && "${aliases[ht]}" == home-status &&
     "${aliases[hs]}" == home-sync && "${aliases[hd]}" == home-doctor &&
     "${aliases[rr]}" == reporoot ]] || fail 'An existing alias changed'
  [[ "${_AD_FN_SOURCE[fh]:t}" == fzf.sh ]] || fail 'History search is not owned by fzf.sh'
  [[ "${_AD_FN_SOURCE[gpp]:t}" == git-core.sh ]] || fail 'Git core commands are missing'
  [[ "${_AD_FN_SOURCE[gmo]:t}" == git-branches.sh ]] || fail 'Branch commands are missing'
  [[ "${_AD_FN_SOURCE[grc]:t}" == git-repos.sh ]] || fail 'Bulk repository commands are missing'
  [[ "${_AD_FN_SOURCE[home-sync]:t}" == home-repos.sh ]] || fail 'Home repository commands are missing'
  [[ "${_AD_FN_SOURCE[notes]:h:t}" == "$OS_NAME" ]] || fail 'Wrong platform notes function'
  if [[ "$OS_NAME" == macos ]]; then
    [[ "${_AD_FN_SOURCE[edit-ghostty]:t}" == functions.sh ]] || fail 'Ghostty editor is still in aliases'
  fi
  [[ "$(gfn --list home-pull)" == *home-pull* ]] || fail 'Git palette lost home-pull'
  [[ "$(fn --list fh)" == *fh* ]] || fail 'Palette lost history search'
  [[ ! -e "$APPDOTS_TEST_GIT_CALLED" ]] || fail 'Startup ran Git'
}
verify 1

# A warm reload must refresh source ownership while preserving all help and
# removing functions retired before this module split.
for name in gps gbm gml gwc gwo gfh repos-update; do
  functions[$name]=':'
  _ad_register "$name" git/legacy "$name" 'Retired fixture.' run
done
# Match normal startup options; optional plugin loaders can return nonzero
# when they are skipped in a non-interactive shell.
set +eu
source "$APPDOTS_TEST_STARTUP"
set -eu
verify 2
for name in gps gbm gml gwc gwo gfh repos-update; do
  (( ! ${+functions[$name]} )) || fail "Retired function survived reload: $name"
  [[ -z "${_AD_FN_GROUP[$name]:-}" ]] || fail "Retired help survived reload: $name"
done
print -r -- "PASS: $APPDOTS_TEST_OS startup, aliases, palette ownership, and reload"
'''

with tempfile.TemporaryDirectory(prefix='appdots-zsh-modules-') as temporary:
    root = Path(temporary)
    bin_dir = root / 'bin'
    bin_dir.mkdir()
    (bin_dir / 'starship').write_text(
        "#!/bin/sh\nprintf '%s\\n' '(( ++APPDOTS_TEST_PROMPT_LOADS ))'\n")
    (bin_dir / 'git').write_text(
        '#!/bin/sh\n: > "$APPDOTS_TEST_GIT_CALLED"\nexit 99\n')
    for command in bin_dir.iterdir():
        command.chmod(0o755)

    for system in ('Linux', 'Darwin'):
        test_home = root / system
        test_home.mkdir()
        (test_home / 'zsh_modules').symlink_to(modules, target_is_directory=True)
        (test_home / '.dotfiles-env.sh').write_text('(( ++APPDOTS_TEST_ENV_LOADS ))\n')
        local_bin = test_home / '.local/bin'
        local_bin.mkdir(parents=True)
        (local_bin / 'env').write_text('(( ++APPDOTS_TEST_LOCAL_LOADS ))\n')
        child_env = os.environ.copy()
        child_env.update({
            'HOME': str(test_home),
            'HOMEBREW_PREFIX': str(root / 'empty-brew'),
            'PATH': str(bin_dir) + os.pathsep + os.environ['PATH'],
            'APPDOTS_TEST_STARTUP': str(startup),
            'APPDOTS_TEST_OS': system,
            'APPDOTS_TEST_GIT_CALLED': str(test_home / 'git-called'),
            'APPDOTS_TEST_ENV_LOADS': '0',
            'APPDOTS_TEST_PROMPT_LOADS': '0',
            'APPDOTS_TEST_LOCAL_LOADS': '0',
        })
        result = subprocess.run([zsh, '-f', '-c', check], env=child_env)
        if result.returncode:
            sys.exit(result.returncode)
PY
