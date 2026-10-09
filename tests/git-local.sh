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
source "$APPDOTS_TEST_REPO/active/shared/HOME/zsh/zsh_modules/shared/git-functions.sh"
fail() { log_err "$*"; exit 1; }
reject() {
  if "$@" > "$APPDOTS_TEST_ROOT/rejected" 2>&1; then
    fail "Unexpected success: $*"
  fi
}
commit_file() {
  print -r -- "$2" > "$1"
  git add -- "$1"
  git commit -qm "$3"
}

repo="$APPDOTS_TEST_ROOT/main checkout"
topic="$APPDOTS_TEST_ROOT/topic checkout"
git init -q -b main "$repo"
cd "$repo"
commit_file base.txt base 'chore: initial commit'
initial="$(git rev-parse HEAD)"
# An unreachable remote makes accidental fetch/pull fail. Review must ignore
# even a remote-tracking main which already points at the topic commit.
git remote add origin "$APPDOTS_TEST_ROOT/nonexistent-remote"
gbc feature/first
[[ "$(git branch --show-current)" == feature/first ]] || fail 'gbc did not switch'
commit_file first.txt first 'feat: first topic'
first="$(git rev-parse HEAD)"
git update-ref refs/remotes/origin/main "$first"
gbi > "$APPDOTS_TEST_ROOT/review"
[[ "$(<"$APPDOTS_TEST_ROOT/review")" == *'feat: first topic'* ]] || fail 'gbi used origin instead of local main'
[[ "$(<"$APPDOTS_TEST_ROOT/review")" == *'+first'* ]] || fail 'gbi omitted patch'
[[ "$(git rev-parse main)" == "$initial" ]] || fail 'review changed main'
gbc feature/second
[[ "$(git rev-parse HEAD)" == "$initial" ]] || fail 'gbc did not default to local main'
reject git rev-parse --verify '@{upstream}'
reject gbc feature/second
reject gbc invalid..branch
reject gbc feature/bad missing-base
reject gbc
reject gmo main main
print dirty > untracked
reject gbc feature/dirty
reject gmo feature/first
rm untracked
gmo feature/first
[[ "$(git branch --show-current)" == main ]] || fail 'gmo did not switch when main had no checkout'
[[ "$(git rev-parse main)" == "$first" ]] || fail 'fast-forward did not advance main'
git show-ref --verify --quiet refs/heads/feature/first || fail 'topic branch was removed'

# Diverged branches create a merge commit, even with merge.ff=only configured.
gbc feature/diverged
commit_file topic.txt topic 'feat: topic side'
diverged="$(git rev-parse HEAD)"
git switch -q main
commit_file main.txt main 'feat: main side'
git config merge.ff only
gmo feature/diverged
[[ "$(git rev-list --parents -n 1 HEAD | wc -w)" -eq 3 ]] || fail 'diverged merge did not have two parents'
git merge-base --is-ancestor "$diverged" HEAD || fail 'topic not merged'
[[ "$(git log -1 --format=%s)" == 'chore: merge feature/diverged into main' ]] || fail 'merge message is not conventional'

git worktree add -q -b feature/worktree "$topic" main
cd "$topic"
commit_file worktree.txt worktree 'feat: worktree topic'
topic_tip="$(git rev-parse HEAD)"
main_tip="$(git rev-parse main)"
print dirty > "$repo/untracked"
reject gmo
[[ "$(git rev-parse main)" == "$main_tip" ]] || fail 'dirty target main changed'
rm "$repo/untracked"
print dirty > source-untracked
reject gmo
cd "$repo"
reject gmo feature/worktree
rm "$topic/source-untracked"
cd "$topic"
print staged > staged.txt
git add staged.txt
reject gmo
git restore --staged staged.txt
rm staged.txt
git update-ref CHERRY_PICK_HEAD HEAD
reject gmo
reject gmi
git update-ref -d CHERRY_PICK_HEAD
mkdir subdir
cd subdir
gmo
[[ "$(git branch --show-current)" == feature/worktree ]] || fail 'gmo switched source worktree'
[[ "$(git -C "$repo" rev-parse HEAD)" == "$topic_tip" ]] || fail 'main worktree was not updated'
[[ -f "$repo/worktree.txt" ]] || fail 'main worktree files were not updated'
cd "$repo"
commit_file update.txt update 'feat: update main'
cd "$topic"
gmi
git merge-base --is-ancestor main HEAD || fail 'gmi did not merge local main'
[[ "$(git branch --show-current)" == feature/worktree ]] || fail 'gmi switched branches'

# Conflicts remain in the destination worktree for normal Git resolution.
commit_file base.txt topic 'feat: conflicting topic'
topic_tip="$(git rev-parse HEAD)"
cd "$repo"
commit_file base.txt main 'feat: conflicting main'
main_tip="$(git rev-parse HEAD)"
cd "$topic"
reject gmo
git -C "$repo" rev-parse --verify MERGE_HEAD >/dev/null || fail 'conflict not left in target worktree'
[[ "$(git rev-parse HEAD)" == "$topic_tip" ]] || fail 'conflict changed source tip'
[[ "$(git rev-parse main)" == "$main_tip" ]] || fail 'conflict changed target tip'
git -C "$repo" merge --abort
git switch -q --detach
reject gmo
reject gmi

git init -q -b master "$APPDOTS_TEST_ROOT/legacy"
cd "$APPDOTS_TEST_ROOT/legacy"
commit_file base.txt base 'chore: initial commit'
gbc bugfix/legacy
[[ "$(git rev-parse HEAD)" == "$(git rev-parse master)" ]] || fail 'master fallback failed'
gbc feature/explicit bugfix/legacy
gbi feature/explicit bugfix/legacy > /dev/null
gmo feature/explicit bugfix/legacy
[[ "$(git branch --show-current)" == bugfix/legacy ]] || fail 'explicit target ignored'

for helper in gbc gbi gmo gmi gmm gpp; do
  [[ -n "${_AD_FN_DESCRIPTION[$helper]:-}" ]] || fail "Unregistered function: $helper"
done
log_ok 'Local Git: creation, review, fast-forward/diverged merges, worktrees, dirty/in-progress guards, conflicts, and base selection passed.'
ZSH
