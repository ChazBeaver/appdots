#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

APPDOTS_TEST_REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
APPDOTS_TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$APPDOTS_TEST_ROOT"' EXIT
export APPDOTS_TEST_REPO APPDOTS_TEST_ROOT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME='Appdots tests' GIT_AUTHOR_EMAIL='tests@example.invalid'
export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME" GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"

zsh -f <<'ZSH'
set -eu
setopt pipefail
source "$APPDOTS_TEST_REPO/lib/log.sh"
registry="$APPDOTS_TEST_REPO/active/shared/HOME/zsh/zsh_modules/shared/00-function-registry.sh"
module="$APPDOTS_TEST_REPO/active/shared/HOME/zsh/zsh_modules/shared/git-functions.sh"
source "$registry"
source "$module"
fail() { log_err "$*"; exit 1; }
reject() {
  if "$@" > "$APPDOTS_TEST_ROOT/rejected" 2>&1; then fail "Unexpected success: $*"; fi
}
commit_file() {
  print -r -- "$2" > "$1"
  git add -- "$1"
  git commit -qm "$3"
}

# Search full metadata independently of the compact display.
matches() {
  _ad_fn_rows git '' | command fzf --exact --delimiter=$'\t' \
    --nth=2..6 --filter="$1" | cut -f3
}
old_matches="$(matches old)"
for name in gbo gbp gbr gbd; do
  [[ "$old_matches" == *"$name"* ]] || fail "Search old missed $name"
done
[[ "$(matches gps)" == gpp ]] || fail 'former push name is not searchable'
[[ "$(matches NUMBER)" == gdf ]] || fail 'usage arguments are not searchable'
for name in gmm gmi gmo; do
  [[ "$(matches merge)" == *"$name"* ]] || fail "Search merge missed $name"
  [[ "${_AD_FN_GROUP[$name]}" == git/merge ]] || fail "Wrong merge group: $name"
done
[[ "$(matches 'delete old')" == *gbd* ]] || fail 'cleanup description is not searchable'
[[ "$(matches 'branch diff')" == *gbv* ]] || fail 'file diff description is not searchable'
for name in ${(k)_AD_FN_DESCRIPTION}; do
  [[ "${_AD_FN_GROUP[$name]}" == git/* ]] || continue
  example="${_AD_FN_EXAMPLE[$name]}"
  [[ "$example" == When:* && "$example" == *$'\nExample:\n'* && "$example" == *$'\nResult:'* ]] || fail "Incomplete explanation: $name"
  [[ "$example" == *$'\n  '"$name"$'\n'* || "$example" == *$'\n  '"$name "* ]] || fail "Missing example command: $name"
  label="${_AD_FN_DESCRIPTION[$name]%%;*}"
  (( ${#label} <= 30 )) || fail "Long picker label: $name"
done

# Reloading the registry preserves other modules while retiring removed names.
sample_function() { :; }
_ad_register sample_function utilities sample_function 'A non-Git function.' view
gps() { :; }
gwc() { :; }
_ad_register gps git/sync gps 'Old push.' run
_ad_register gwc git/worktree gwc 'Old worktree.' run
_AD_FN_OWNED=()
source "$registry"
_ad_fn_owned gpp || fail 'registry reload did not restore an owned function'
source "$module"
[[ -n "${_AD_FN_DESCRIPTION[sample_function]:-}" ]] || fail 'registry reload lost other functions'
_ad_fn_owned sample_function && fail 'function from outside appdots was marked as owned'
for name in gps gwc gwo gml gbm; do
  (( ! ${+functions[$name]} )) || fail "Retired function remains callable: $name"
  [[ -z "${_AD_FN_DESCRIPTION[$name]:-}" ]] || fail "Retired registry entry remains: $name"
done
COLUMNS=80 gfh --list > "$APPDOTS_TEST_ROOT/help-list"
awk 'length($0) > 80 { exit 1 }' "$APPDOTS_TEST_ROOT/help-list" || fail 'printable help overflows 80 columns'

# Exercise the actual fn/gfh invocation with a non-interactive fzf adapter.
# It preserves filtering and captures layout flags instead of opening a UI.
export APPDOTS_TEST_FZF_REAL="$(command -v fzf)"
mkdir "$APPDOTS_TEST_ROOT/bin"
cat > "$APPDOTS_TEST_ROOT/bin/fzf" <<'PY'
#!/usr/bin/env python3
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
args = sys.argv[1:]
if any(a.startswith('--filter=') for a in args):
    os.execv(os.environ['APPDOTS_TEST_FZF_REAL'], ['fzf', *args])
(Path(os.environ['APPDOTS_TEST_ROOT']) / 'fzf-args.json').write_text(json.dumps(args))
query = next(a.split('=', 1)[1] for a in args if a.startswith('--query='))
reload = next(a for a in args if a.startswith('--bind=start:reload-sync('))
reload = reload.removeprefix('--bind=start:reload-sync(').split('),change:')[0]
result = subprocess.run(reload.replace('{q}', shlex.quote(query)), shell=True,
                        text=True, capture_output=True)
if result.returncode:
    sys.exit(result.returncode)
rows = [row for row in result.stdout.splitlines() if row]
if not rows:
    sys.exit(130)
print(os.environ.get('APPDOTS_TEST_FZF_KEY', '') + '\n' + rows[0])
PY
chmod +x "$APPDOTS_TEST_ROOT/bin/fzf"
test_path_before="$PATH"
export PATH="$APPDOTS_TEST_ROOT/bin:$PATH"
export TMPDIR="$APPDOTS_TEST_ROOT"
[[ "$(COLUMNS=80 gfh gps)" == gpp ]] || fail 'interactive help did not find/return renamed push'
# Examples and definitions are output only; selecting a bulk helper must
# return its explanation without calling it or placing it at the prompt.
example="$(APPDOTS_TEST_FZF_KEY=ctrl-e gfh grc)"
[[ "$example" == *'grc ~/Projects/example "chore: update examples"'* && "$example" == *'adds all files'* ]] || fail 'Ctrl-E did not print the example and its effect'
example="$(APPDOTS_TEST_FZF_KEY=ctrl-e gfh NUMBER)"
[[ "$example" == *'gdf 3'* && "$example" == *'compares HEAD~3 with HEAD'* ]] || fail 'Ctrl-E did not explain the hidden usage match'
definition="$(APPDOTS_TEST_FZF_KEY=ctrl-f gfh gdf)"
[[ "$definition" == *'gdf ()'* && "$definition" == *'git diff --name-only'* ]] || fail 'Ctrl-F did not print the function'
unsafe_query="no-match'; touch $APPDOTS_TEST_ROOT/injected; #"
[[ -z "$(gfh "$unsafe_query")" ]] || fail 'unmatched query selected a command'
[[ ! -e "$APPDOTS_TEST_ROOT/injected" ]] || fail 'search query was executed'

# fn uses the same keys for shared and platform-specific functions.
source "$APPDOTS_TEST_REPO/active/shared/HOME/zsh/zsh_modules/shared/functions.sh"
source "$APPDOTS_TEST_REPO/active/shared/HOME/zsh/zsh_modules/shared/fzf.sh"
example="$(APPDOTS_TEST_FZF_KEY=ctrl-e fn mkcd)"
[[ "$example" == *'mkcd ~/Projects/example'* && "$example" == *'The shell then changes'* ]] || fail 'fn Ctrl-E did not explain a shared function'
definition="$(APPDOTS_TEST_FZF_KEY=ctrl-f fn edit-zshrc)"
[[ "$definition" == *'edit-zshrc ()'* && "$definition" == *'vim $HOME/.zshrc'* ]] || fail 'fn Ctrl-F did not print a shared function'
source "$APPDOTS_TEST_REPO/active/shared/HOME/zsh/zsh_modules/shared/functions.sh"
for scope in linux macos; do
  (
    source "$APPDOTS_TEST_REPO/active/shared/HOME/zsh/zsh_modules/$scope/functions.sh"
    [[ "$scope" == linux ]] || source "$APPDOTS_TEST_REPO/active/shared/HOME/zsh/zsh_modules/macos/alias.sh"
    for name in ${(k)_AD_FN_DESCRIPTION}; do
      [[ "$name" == sample_function ]] && continue
      _ad_fn_owned "$name" || fail "Own $scope function was hidden: $name"
      example="${_AD_FN_EXAMPLE[$name]}"
      [[ "$example" == When:* && "$example" == *$'\nExample:\n'* && "$example" == *$'\nResult:'* ]] || fail "Incomplete $scope example: $name"
      while IFS= read -r line; do
        (( ${#line} <= 78 )) || fail "Long $scope example line: $name"
      done <<< "$example"
    done
    example="$(APPDOTS_TEST_FZF_KEY=ctrl-e fn notes)"
    if [[ "$scope" == linux ]]; then
      [[ "$example" == *'~/Documents/notes'* ]] || fail 'fn Linux notes example is wrong'
    else
      [[ "$example" == *'~/Projects/work/notes'* ]] || fail 'fn macOS notes example is wrong'
    fi
  ) || fail "fn examples failed for $scope"
done
# A foreign registration and a foreign replacement of an owned name stay out
# of both the picker and explicit source inspection.
foreign_file="$APPDOTS_TEST_ROOT/foreign-functions.zsh"
cat > "$foreign_file" <<'FOREIGN_ZSH'
foreign_function() { :; }
home() { :; }
_ad_register foreign_function utilities foreign_function 'Foreign function.' view
FOREIGN_ZSH
(
  source "$foreign_file"
  rows="$(_ad_fn_rows '' '')"
  [[ "$rows" != *$'\tforeign_function\t'* ]] || fail 'foreign registration reached fn'
  [[ "$rows" != *$'\thome\t'* ]] || fail 'foreign replacement reached fn'
  reject fn --source foreign_function
  reject fn --source home
) || fail 'fn ownership check failed'
snapshots=( "$APPDOTS_TEST_ROOT"/appdots-functions.*(N) )
(( ${#snapshots} == 0 )) || fail 'picker left temporary snapshots behind'
source "$module"
export PATH="$test_path_before"
python3 - <<'PY'
import json
import os
from pathlib import Path
args = json.loads((Path(os.environ['APPDOTS_TEST_ROOT']) / 'fzf-args.json').read_text())
assert '--no-wrap' in args and '--no-hscroll' in args
assert '--with-nth=1,3,2,8' in args and '--disabled' in args
assert '--expect=ctrl-e,ctrl-f' in args
assert '--preview-window=down,35%,wrap,hidden' in args
header = next(a.split('=', 1)[1] for a in args if a.startswith('--header='))
assert header == 'ctrl-e: example  ctrl-f: function'
PY

# Branch cleanup: spaces/quotes in paths, quote in branch, gone upstreams,
# and branches held by other worktrees must not produce unsafe candidates.
repo="$APPDOTS_TEST_ROOT/cleanup repo's checkout"
remote="$APPDOTS_TEST_ROOT/cleanup remote.git"
git init -q --bare "$remote"
git init -q -b main "$repo"
cd "$repo"
commit_file base.txt base 'chore: initial commit'
git remote add origin "$remote"
git push -q -u origin main
git branch feature/merged
git branch "feature/with'quote"
git worktree add -q -b feature/open "$APPDOTS_TEST_ROOT/open checkout" main
git switch -qc feature/unmerged
commit_file extra.txt extra 'feat: unmerged work'
git switch -q main
for name in feature/merged feature/unmerged; do
  git config "branch.$name.remote" origin
  git config "branch.$name.merge" "refs/heads/$name"
done
gbp > "$APPDOTS_TEST_ROOT/prune"
[[ "$(<"$APPDOTS_TEST_ROOT/prune")" == *feature/unmerged* ]] || fail 'gone upstream report missing branch'
gbr main > "$APPDOTS_TEST_ROOT/report"
[[ "$(<"$APPDOTS_TEST_ROOT/report")" == *'feature/open (checked out:'* ]] || fail 'report omitted worktree occupancy'
# Select every offered candidate and capture the queued command, never a UI.
fzf() { tee "$APPDOTS_TEST_ROOT/candidates"; }
# Capture exact prompt bytes: read -z parses/dequotes the buffer itself.
print() {
  if [[ "${1:-}" == -z ]]; then
    shift
    [[ "${1:-}" == -- ]] && shift
    builtin print -r -- "$1" > "$APPDOTS_TEST_ROOT/deletion"
  else
    builtin print "$@"
  fi
}
gbd main
unfunction print
deletion="$(<"$APPDOTS_TEST_ROOT/deletion")"
candidates="$(<"$APPDOTS_TEST_ROOT/candidates")"
[[ "$candidates" == *feature/merged* && "$candidates" == *"feature/with'quote"* ]] || fail 'merged branch missing'
[[ "$candidates" != *feature/unmerged* && "$candidates" != *feature/open* && "$candidates" != *main* ]] || fail 'unsafe branch offered for deletion'
[[ "$deletion" != *' -D '* ]] || fail 'cleanup generated force deletion'
eval "$deletion" > /dev/null
reject git show-ref --verify --quiet refs/heads/feature/merged
reject git show-ref --verify --quiet "refs/heads/feature/with'quote"
git show-ref --verify --quiet refs/heads/feature/unmerged || fail 'unmerged branch deleted'
git show-ref --verify --quiet refs/heads/feature/open || fail 'checked-out branch deleted'
unfunction fzf

# Bulk operations use local bare remotes; nothing contacts an external server.
parent="$APPDOTS_TEST_ROOT/repos"
remote="$APPDOTS_TEST_ROOT/bulk remote.git"
seed="$APPDOTS_TEST_ROOT/seed"
git init -q --bare -b main "$remote"
git init -q -b main "$seed"
cd "$seed"
commit_file seed.txt seed 'chore: initial commit'
git remote add origin "$remote"
git push -q -u origin main
mkdir -p "$parent/ordinary directory"
git clone -q "$remote" "$parent/good"
git clone -q "$remote" "$parent/bad"
git -C "$parent/bad" remote set-url origin "$APPDOTS_TEST_ROOT/missing-remote"
commit_file new.txt new 'feat: remote update'
git push -q
reject grp "$parent"
git -C "$parent/good" merge-base --is-ancestor main origin/main || fail 'good child not processed after peer failure'
[[ -f "$parent/good/new.txt" ]] || fail 'successful pull did not update files'
reject grr "$parent"
reject grp "$APPDOTS_TEST_ROOT/missing-parent"
reject grr "$APPDOTS_TEST_ROOT/missing-parent"
reject grs "$APPDOTS_TEST_ROOT/missing-parent"
reject grc "$APPDOTS_TEST_ROOT/missing-parent" 'chore: test'

# grs reports a broken repository as a failure, not a clean checkout.
mkdir -p "$parent/broken/.git"
reject grs "$parent"
[[ "$(<"$APPDOTS_TEST_ROOT/rejected")" == *'Status failed:'* ]] || fail 'broken status was hidden'
rm -rf "$parent/broken"
grs "$parent" > /dev/null

# A normal subdirectory inherits its parent's Git context, but must never be
# treated as a separate child repository. No commit may be made in the parent.
cd "$seed"
before="$(git rev-parse HEAD)"
mkdir -p normal-subdir
print dirty > normal-subdir/untracked
grc "$seed" 'chore: must not be committed' > /dev/null
[[ "$(git rev-parse HEAD)" == "$before" ]] || fail 'bulk command committed in parent'
git status --porcelain | grep -q normal-subdir || fail 'parent changes staged unexpectedly'

# Failed pushes keep the new commit, return failure, and do not block peers.
print good > "$parent/good/good.txt"
print bad > "$parent/bad/bad.txt"
reject grc "$parent" 'feat: bulk changes'
[[ -f "$parent/good/good.txt" ]] || fail 'good child changed unexpectedly'
[[ "$(git -C "$parent/good" log -1 --format=%s)" == 'feat: bulk changes' ]] || fail 'good child not committed'
[[ "$(git -C "$parent/bad" log -1 --format=%s)" == 'feat: bulk changes' ]] || fail 'failed push lost local commit'
git -C "$parent/good" diff --quiet origin/main HEAD || fail 'good child not pushed'

# Retrying a clean checkout pushes retained commits without trying an empty commit.
retry_remote="$APPDOTS_TEST_ROOT/retry.git"
git init -q --bare -b main "$retry_remote"
git -C "$parent/bad" remote set-url origin "$retry_remote"
grc "$parent" 'chore: retry push' > /dev/null
[[ "$(git -C "$parent/bad" log -1 --format=%s)" == 'feat: bulk changes' ]] || fail 'retry created an empty commit'
[[ "$(git --git-dir="$retry_remote" rev-parse main)" == "$(git -C "$parent/bad" rev-parse HEAD)" ]] || fail 'retained commit not pushed'

# Detached and in-progress checkouts must not be staged/committed by grc.
git -C "$parent/bad" switch -q --detach
print detached > "$parent/bad/detached.txt"
reject grc "$parent" 'chore: detached'
git -C "$parent/bad" diff --cached --quiet || fail 'detached checkout was staged'
git -C "$parent/bad" switch -q main
git -C "$parent/bad" update-ref CHERRY_PICK_HEAD HEAD
reject grp "$parent"
reject grr "$parent"
reject grc "$parent" 'chore: unfinished operation'
git -C "$parent/bad" diff --cached --quiet || fail 'in-progress checkout was staged'
git -C "$parent/bad" update-ref -d CHERRY_PICK_HEAD
rm "$parent/bad/detached.txt"

# Commit-hook rejection is a failure, leaves staging intact, and never pushes.
remote_before="$(git --git-dir="$remote" rev-parse main)"
printf '#!/bin/sh\nexit 1\n' > "$parent/good/.git/hooks/pre-commit"
chmod +x "$parent/good/.git/hooks/pre-commit"
print rejected > "$parent/good/rejected.txt"
reject grc "$parent" 'chore: rejected commit'
reject git -C "$parent/good" diff --cached --quiet
[[ "$(git --git-dir="$remote" rev-parse main)" == "$remote_before" ]] || fail 'hook failure still pushed'

# Missing origin is diagnosed before staging or committing that child.
git init -q -b main "$parent/no-origin"
cd "$parent/no-origin"
commit_file base.txt base 'chore: local repository'
print local > local.txt
reject grc "$parent" 'chore: missing origin'
git diff --cached --quiet || fail 'missing-origin child was staged'
[[ "$(git log -1 --format=%s)" == 'chore: local repository' ]] || fail 'missing-origin child was committed'
log_ok 'Function palette and Git tools: search, ownership, examples, cleanup, bulk failures, and push retries passed.'
ZSH
