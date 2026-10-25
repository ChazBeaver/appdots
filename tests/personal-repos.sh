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
source "$APPDOTS_TEST_REPO/active/shared/HOME/zsh/zsh_modules/shared/00-function-registry.sh"
fail() { log_err "$*"; exit 1; }
reject() {
  if "$@" > "$APPDOTS_TEST_ROOT/rejected" 2>&1; then
    fail "Unexpected success: $*"
  fi
}

# Loading the replacement performs no Git operations. The old modules must
# be absent because .zshrc sources every *.sh in shared/ and the OS scope.
repos-update() { fail 'Retired repos-update definition was called'; }
_ad_register repos-update git/repos repos-update 'Old updater.' run
git() { fail 'Sourcing Git helpers invoked Git'; }
source "$APPDOTS_TEST_REPO/active/shared/HOME/zsh/zsh_modules/shared/alias.sh"
source "$APPDOTS_TEST_REPO/active/shared/HOME/zsh/zsh_modules/shared/git-functions.sh"
unfunction git
for module in shared/personal-repos-pull.sh linux/hyprdots-pull.sh; do
  [[ ! -e "$APPDOTS_TEST_REPO/active/shared/HOME/zsh/zsh_modules/$module" ]] || fail "Startup pull still installed: $module"
done
_ad_fn_owned home-pull || fail 'home-pull is missing from the function palette'
(( ! ${+functions[repos-update]} )) || fail 'retired repos-update remains callable after reload'
[[ -z "${_AD_FN_DESCRIPTION[repos-update]:-}" ]] || fail 'retired registry entry remains after reload'
[[ "${aliases[hp]:-}" == home-pull ]] || fail 'hp does not alias home-pull'
[[ "${aliases[ht]:-}" == home-status ]] || fail 'ht does not alias home-status'
_ad_fn_owned home-status || fail 'home-status is missing from the palette'
_ad_fn_matches home-status git ht || fail 'status alias is not searchable'
_ad_fn_matches home-pull git hp || fail 'short alias is not searchable'
_ad_fn_matches home-pull git repos-update || fail 'former updater name is not searchable'
for action in sync doctor; do
  _ad_fn_owned "home-$action" || fail "home-$action is missing from the palette"
  [[ "${_AD_FN_GROUP[home-$action]}" == projects ]] || fail "Wrong group for home-$action"
done
[[ "${aliases[hs]:-}" == home-sync ]] || fail 'hs does not alias home-sync'
[[ "${aliases[hd]:-}" == home-doctor ]] || fail 'hd does not alias home-doctor'
_ad_fn_matches home-sync projects hs || fail 'sync alias is not searchable'
_ad_fn_matches home-doctor projects hd || fail 'doctor alias is not searchable'

# APPDOTS_ENV_FILE also serves diagnostics; fixtures never change HOME or
# write the real registry. All remotes are local disposable bare repositories.
export APPDOTS_ENV_FILE="$APPDOTS_TEST_ROOT/registry.sh"
reject home-pull
print '# No installed repositories' > "$APPDOTS_ENV_FILE"
reject home-pull
reject home-pull unexpected-argument
for action in sync doctor status; do
  reject "home-$action"
  reject "home-$action" unexpected-argument
done

remote="$APPDOTS_TEST_ROOT/remote.git"
seed="$APPDOTS_TEST_ROOT/seed"
git init -q --bare -b main "$remote"
git init -q -b main "$seed"
print base > "$seed/base.txt"
git -C "$seed" add base.txt
git -C "$seed" commit -qm 'chore: initial commit'
git -C "$seed" remote add origin "$remote"
git -C "$seed" push -qu origin main
initial="$(git -C "$seed" rev-parse HEAD)"
for name in dirty detached unfinished diverged no-upstream offline good custom unregistered worktree-owner; do
  git clone -q "$remote" "$APPDOTS_TEST_ROOT/$name"
done
git -C "$APPDOTS_TEST_ROOT/dirty" config merge.autoStash true
git -C "$APPDOTS_TEST_ROOT/dirty" config pull.autostash true
print changed >> "$APPDOTS_TEST_ROOT/dirty/base.txt"
git -C "$APPDOTS_TEST_ROOT/dirty" add base.txt
print untracked > "$APPDOTS_TEST_ROOT/dirty/untracked.txt"
git -C "$APPDOTS_TEST_ROOT/detached" switch -q --detach
git -C "$APPDOTS_TEST_ROOT/unfinished" update-ref CHERRY_PICK_HEAD HEAD
print local > "$APPDOTS_TEST_ROOT/diverged/local.txt"
git -C "$APPDOTS_TEST_ROOT/diverged" add local.txt
git -C "$APPDOTS_TEST_ROOT/diverged" commit -qm 'feat: local work'
diverged_tip="$(git -C "$APPDOTS_TEST_ROOT/diverged" rev-parse HEAD)"
git -C "$APPDOTS_TEST_ROOT/diverged" config pull.rebase true
git -C "$APPDOTS_TEST_ROOT/no-upstream" branch --unset-upstream
git -C "$APPDOTS_TEST_ROOT/offline" remote set-url origin "$APPDOTS_TEST_ROOT/missing.git"
git -C "$APPDOTS_TEST_ROOT/custom" remote rename origin elsewhere
git -C "$APPDOTS_TEST_ROOT/custom" branch -m local-name
git -C "$APPDOTS_TEST_ROOT/worktree-owner" worktree add -q --track -b linked "$APPDOTS_TEST_ROOT/linked worktree" origin/main
mv "$APPDOTS_TEST_ROOT/good" "$APPDOTS_TEST_ROOT/good repo's checkout"
ln -s "$APPDOTS_TEST_ROOT/good repo's checkout" "$APPDOTS_TEST_ROOT/duplicate"
mkdir "$seed/ordinary-folder"
print remote > "$seed/remote.txt"
git -C "$seed" add remote.txt
git -C "$seed" commit -qm 'feat: update from another machine'
git -C "$seed" push -q
remote_tip="$(git -C "$seed" rev-parse HEAD)"

# A future repo name needs no code change. Paths are resolved by sourcing
# the registry, including variable expansion and spaces/quotes in paths.
cat > "$APPDOTS_ENV_FILE" <<'ENV'
export DIRTY_DIR="$APPDOTS_TEST_ROOT/dirty"
export DETACHED_DIR="$APPDOTS_TEST_ROOT/detached"
export UNFINISHED_DIR="$APPDOTS_TEST_ROOT/unfinished"
export DIVERGED_DIR="$APPDOTS_TEST_ROOT/diverged"
export NO_UPSTREAM_DIR="$APPDOTS_TEST_ROOT/no-upstream"
export OFFLINE_DIR="$APPDOTS_TEST_ROOT/offline"
export APP_DOTS_DIR="$APPDOTS_TEST_ROOT/good repo's checkout"
alias appdots='cd "$APP_DOTS_DIR"'
export FUTURE_REPO_DIR="$APPDOTS_TEST_ROOT/custom"
export LINKED_DIR="$APPDOTS_TEST_ROOT/linked worktree"
export DUPLICATE_DIR="$APPDOTS_TEST_ROOT/duplicate"
export MISSING_DIR="$APPDOTS_TEST_ROOT/not-installed"
export NONREPO_DIR="$APPDOTS_TEST_ROOT/seed/ordinary-folder"
export EMPTY_DIR=""
ENV
export UNREGISTERED_DIR="$APPDOTS_TEST_ROOT/unregistered"
export APP_DOTS_DIR='caller value must survive'
aliases[appdots]='caller-alias'
before_pwd="$PWD"
reject home-pull
report="$(<"$APPDOTS_TEST_ROOT/rejected")"
[[ "$report" == *'home-pull: 3 succeeded, 6 failed, 3 skipped'* ]] || fail "Wrong summary: $report"
[[ "$APP_DOTS_DIR" == 'caller value must survive' && "${aliases[appdots]}" == caller-alias ]] || fail 'registry exports/aliases leaked into the caller'
[[ "$PWD" == "$before_pwd" ]] || fail 'updating changed the caller directory'
for name in "good repo's checkout" custom 'linked worktree'; do
  [[ "$(git -C "$APPDOTS_TEST_ROOT/$name" rev-parse HEAD)" == "$remote_tip" ]] || fail "Checkout did not update: $name"
done
for name in dirty detached unfinished no-upstream offline unregistered; do
  [[ "$(git -C "$APPDOTS_TEST_ROOT/$name" rev-parse HEAD)" == "$initial" ]] || fail "Checkout changed unexpectedly: $name"
done
[[ "$(git -C "$APPDOTS_TEST_ROOT/diverged" rev-parse HEAD)" == "$diverged_tip" ]] || fail 'diverged local commit was changed'
[[ -f "$APPDOTS_TEST_ROOT/dirty/untracked.txt" ]] || fail 'untracked file lost'
reject git -C "$APPDOTS_TEST_ROOT/dirty" diff --cached --quiet
[[ -z "$(git -C "$APPDOTS_TEST_ROOT/dirty" stash list)" ]] || fail 'dirty checkout was stashed'
[[ -f "$APPDOTS_TEST_ROOT/unfinished/.git/CHERRY_PICK_HEAD" ]] || fail 'unfinished Git operation changed'

# Status reports local work, detached HEADs, and cached upstream counts without
# contacting remotes, including the deliberately unreachable offline remote.
git() {
  local argument
  for argument in "$@"; do
    [[ "$argument" != fetch && "$argument" != pull ]] || fail 'status contacted a remote'
  done
  command git "$@"
}
ht > "$APPDOTS_TEST_ROOT/status" 2>&1
unfunction git
report="$(<"$APPDOTS_TEST_ROOT/status")"
[[ "$report" == *'home-status: 9 succeeded, 0 failed, 3 skipped'* ]] || fail "Wrong status summary: $report"
[[ "$report" == *'M  base.txt'* && "$report" == *'?? untracked.txt'* ]] || fail 'status omitted local changes'
[[ "$report" == *'## HEAD (no branch)'* ]] || fail 'status omitted detached HEAD'
[[ "$report" == *'[ahead 1, behind 1]'* ]] || fail 'status omitted cached divergence'
[[ "$report" == *'## local-name...elsewhere/main'* ]] || fail 'status assumed origin or matching branch names'

# Re-read the file each time, ignoring inherited variables from earlier runs.
# No trailing newline and duplicate declarations are both valid registry data.
printf 'export NEW_REPO_DIR="$APPDOTS_TEST_ROOT/unregistered"\nexport SAME_REPO_DIR="$APPDOTS_TEST_ROOT/unregistered"' > "$APPDOTS_ENV_FILE"
hp > "$APPDOTS_TEST_ROOT/success" 2>&1
[[ "$(git -C "$UNREGISTERED_DIR" rev-parse HEAD)" == "$remote_tip" ]] || fail 'fresh registry entry was not discovered'
[[ "$(<"$APPDOTS_TEST_ROOT/success")" == *'home-pull: 1 succeeded, 0 failed, 0 skipped'* ]] || fail 'duplicate updated more than once'

mkdir -p "$APPDOTS_TEST_ROOT/broken/.git"
printf 'export BROKEN_DIR="$APPDOTS_TEST_ROOT/broken"\nexport GOOD_DIR="$APPDOTS_TEST_ROOT/unregistered"\n' > "$APPDOTS_ENV_FILE"
reject home-status
[[ "$(<"$APPDOTS_TEST_ROOT/rejected")" == *'home-status: 1 succeeded, 1 failed, 0 skipped'* ]] || fail 'status hid a broken checkout or stopped processing'

# Scripts execute rather than being sourced, run from their own checkout,
# retain the exported registry, and cannot leak shell state into the caller.
for name in scripts-fail scripts-good scripts-absent scripts-disabled; do
  git init -q "$APPDOTS_TEST_ROOT/$name"
done
for action in sync doctor; do
  for name in scripts-fail scripts-good scripts-disabled; do
    cat > "$APPDOTS_TEST_ROOT/$name/$action.sh" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\t%s\n' "$(basename "$0")" "$PWD" >> "$APPDOTS_TEST_ROOT/script-runs"
[[ "$SCRIPTS_GOOD_DIR" == "$APPDOTS_TEST_ROOT/scripts-good" ]] || exit 40
[[ -f relative-input ]] || exit 41
export APPDOTS_TEST_SCRIPT_LEAK=changed
cd /
[[ "$0" != *install.sh ]] || exit 42
if [[ "$OLDPWD" == *scripts-fail ]]; then exit 7; fi
SCRIPT
    print relative > "$APPDOTS_TEST_ROOT/$name/relative-input"
    [[ "$name" == scripts-disabled ]] || chmod +x "$APPDOTS_TEST_ROOT/$name/$action.sh"
  done
done
ln -s "$APPDOTS_TEST_ROOT/scripts-good" "$APPDOTS_TEST_ROOT/scripts-duplicate"
# A missing sync must never fall back to install.sh or bootstrap.sh.
for script in install bootstrap; do
  printf '#!/bin/sh\nexit 99\n' > "$APPDOTS_TEST_ROOT/scripts-absent/$script.sh"
  chmod +x "$APPDOTS_TEST_ROOT/scripts-absent/$script.sh"
done
cat > "$APPDOTS_ENV_FILE" <<'ENV'
export SCRIPTS_FAIL_DIR="$APPDOTS_TEST_ROOT/scripts-fail"
export SCRIPTS_GOOD_DIR="$APPDOTS_TEST_ROOT/scripts-good"
export SCRIPTS_DUPLICATE_DIR="$APPDOTS_TEST_ROOT/scripts-duplicate"
export SCRIPTS_ABSENT_DIR="$APPDOTS_TEST_ROOT/scripts-absent"
export SCRIPTS_DISABLED_DIR="$APPDOTS_TEST_ROOT/scripts-disabled"
export MISSING_DIR="$APPDOTS_TEST_ROOT/not-installed"
ENV
export SCRIPTS_GOOD_DIR='caller value must survive'
export APPDOTS_TEST_SCRIPT_LEAK=original
for action in sync doctor; do
  : > "$APPDOTS_TEST_ROOT/script-runs"
  reject "home-$action"
  report="$(<"$APPDOTS_TEST_ROOT/rejected")"
  [[ "$report" == *"home-$action: 1 succeeded, 2 failed, 2 skipped"* ]] || fail "Wrong $action summary: $report"
  [[ "$report" == *'(exit 7)'* ]] || fail "$action hid the script exit status"
  expected="$(printf '%s.sh\t%s\n%s.sh\t%s' "$action" "$APPDOTS_TEST_ROOT/scripts-fail" "$action" "$APPDOTS_TEST_ROOT/scripts-good")"
  [[ "$(<"$APPDOTS_TEST_ROOT/script-runs")" == "$expected" ]] || fail "$action ran out of order, ran twice, or ran an invalid script"
  [[ "$PWD" == "$before_pwd" ]] || fail "$action changed the caller directory"
  [[ "$SCRIPTS_GOOD_DIR" == 'caller value must survive' && "$APPDOTS_TEST_SCRIPT_LEAK" == original ]] || fail "$action leaked script or registry state"
done
printf 'export SCRIPTS_GOOD_DIR="$APPDOTS_TEST_ROOT/scripts-good"\n' > "$APPDOTS_ENV_FILE"
hs > "$APPDOTS_TEST_ROOT/synced" 2>&1
hd > "$APPDOTS_TEST_ROOT/diagnosed" 2>&1
[[ "$(<"$APPDOTS_TEST_ROOT/synced")" == *'home-sync: 1 succeeded, 0 failed, 0 skipped'* ]] || fail 'hs failed'
[[ "$(<"$APPDOTS_TEST_ROOT/diagnosed")" == *'home-doctor: 1 succeeded, 0 failed, 0 skipped'* ]] || fail 'hd failed'
log_ok 'Personal repository helpers: discovery, pulls, script execution, aliases, state isolation, and failure handling passed.'
ZSH
