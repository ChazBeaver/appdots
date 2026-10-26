# Common Git safeguards, single-checkout commands, and Git help.
# The other Git modules and home-repos.sh reuse these helpers.

# Remove retired definitions when this module is reloaded in an existing shell.
# Former names remain searchable in their replacement's registry entry.
for _ad_retired_git_name in gps gbm gml gwc gwo gfh repos-update; do
  unfunction "$_ad_retired_git_name" 2>/dev/null || true
  unset "_AD_FN_GROUP[$_ad_retired_git_name]" "_AD_FN_USAGE[$_ad_retired_git_name]" \
    "_AD_FN_DESCRIPTION[$_ad_retired_git_name]" "_AD_FN_EFFECT[$_ad_retired_git_name]" \
    "_AD_FN_LEGACY[$_ad_retired_git_name]" "_AD_FN_SOURCE[$_ad_retired_git_name]" \
    "_AD_FN_EXAMPLE[$_ad_retired_git_name]" "_AD_FN_OWNED[$_ad_retired_git_name]"
done
unset _ad_retired_git_name

_ad_gr_summary() {
  printf '%s: %s succeeded, %s failed, %s skipped\n' "$1" "$2" "$3" "$4"
  (( $3 == 0 ))
}

_ad_git_idle() {
  local dir="$1" git_dir operation
  git_dir="$(git -C "$dir" rev-parse --absolute-git-dir)" || return 1
  for operation in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD rebase-merge rebase-apply sequencer BISECT_START; do
    if [[ -e "$git_dir/$operation" ]]; then
      print -u2 -r -- "Finish or abort the Git operation in $dir first ($operation)."
      return 1
    fi
  done
}

_ad_gb_clean() {
  local dir="$1" changes
  _ad_git_idle "$dir" || return 1
  changes="$(git -C "$dir" status --porcelain --untracked-files=normal)" || return 1
  if [[ -n "$changes" ]]; then
    print -u2 -r -- "Commit or stash changes in $dir first (including untracked files)."
    return 1
  fi
}

# Git stash current work, pull updates, stash pop work back in place
gsp() {
  local message="stashing to pull latest"
  local stash_before stash_after current_stash
  local -i made_stash=0

  stash_before="$(git rev-parse --verify -q refs/stash 2>/dev/null || true)"

  echo "🔒 Stashing current changes..."
  git stash push -m "$message" || return 1

  stash_after="$(git rev-parse --verify -q refs/stash 2>/dev/null || true)"
  if [[ -n "$stash_after" && "$stash_after" != "$stash_before" ]]; then
    made_stash=1
  else
    echo "ℹ️  No tracked changes needed stashing."
  fi

  echo "⬇️  Pulling latest changes from remote..."
  git pull || {
    (( made_stash )) && echo "❌ git pull failed. The new stash remains in place."
    return 1
  }

  if (( made_stash )); then
    current_stash="$(git rev-parse --verify -q refs/stash 2>/dev/null || true)"
    if [[ "$current_stash" != "$stash_after" ]]; then
      echo "⚠️  The stash stack changed during pull; the new stash was not popped."
      return 1
    fi

    echo "🔓 Re-applying stashed changes..."
    git stash pop || {
      echo "⚠️  git stash pop failed — resolve any conflicts manually."
      return 1
    }
  fi

  if (( made_stash )); then
    echo "✅ Done: pulled latest and reapplied your changes."
  else
    echo "✅ Done: pulled latest; no local stash was needed."
  fi
}

_ad_register gsp git/sync gsp 'Stash, pull, and restore; Save tracked changes and pull with the configured remote and branch.' run stashpull \
    'When: You need to pull updates while you have tracked file changes.
The current branch must have a configured upstream or other pull settings.
Example:
  gsp
Result: The function saves tracked changes in a new stash if necessary.
It runs git pull with your configured remote, branch, and pull settings.
After a successful pull, it applies and removes only the stash it created.
Untracked files stay in the checkout.
Previously staged changes can return as unstaged changes.

If the pull fails, the new stash remains available.
If stash restoration causes conflicts, Git keeps that stash.
Use git status and git stash list to inspect a failure before you continue.'

# =========================
# Git Push/Pull helpers
# =========================

# Git Push Origin Upstream (unchanged)
gpp() {
  local branch
  branch=$(git symbolic-ref --short HEAD 2>/dev/null)

  if [ -z "$branch" ]; then
    echo "❌ Not on a Git branch or not a Git repository."
    return 1
  fi

  echo "🚀 Pushing '$branch' to origin with upstream tracking..."
  git push -u origin "$branch"
}

_ad_register gpp git/sync gpp 'Push branch to origin; Push existing commits and set upstream tracking for the current branch.' run 'gps gpush' \
    'When: You are on feature/foo and need to publish its local commits.
Commit the necessary changes before you run this command.
Example:
  gpp
Result: The function pushes feature/foo to the origin remote.
It sets origin/feature/foo as the upstream branch after a successful push.
The function needs a current branch and an origin remote.
If the push fails, the local commits remain in the repository.'

# Git Pull Origin (same spirit as gpp)
# - pulls origin/<current-branch>
# - does NOT set upstream (pull doesn't need -u; upstream is set by gpp)
gpl() {
  local branch
  branch=$(git symbolic-ref --short HEAD 2>/dev/null)

  if [ -z "$branch" ]; then
    echo "❌ Not on a Git branch or not a Git repository."
    return 1
  fi

  echo "⬇️  Pulling 'origin/$branch' into '$branch'..."
  git pull origin "$branch"
}

_ad_register gpl git/sync gpl 'Pull branch from origin; Pull the remote branch with the same name as the current branch.' run gpull \
    'When: You are on feature/foo and need new commits from origin/feature/foo.
Example:
  gpl
Result: The function pulls origin/feature/foo into your current branch.
It selects origin and the current branch name, regardless of its upstream.
Git uses your pull settings to merge, rebase, or require a fast-forward.
If the pull fails, use git status to check the repository before you continue.
Use gmm when you need updates from origin/main.'

# ---------- gfn: searchable Git function help ----------
gfn() {
  local _AD_FN_CONTEXT_EXACT=1

  fn --group git "$@"
}

_ad_register gfn git/help 'gfn [--list] [QUERY]' 'Search Git functions; Find helpers for branches, merges, diffs, and cleanup.' view 'gfh gbh' \
    'When: You need to find a Git function for a task.
Example:
  gfn old
Result: The picker shows Git functions for old or stale branches.
The search includes descriptions, arguments, and former names.
Press Ctrl-E to close the picker and show the example.
Press Ctrl-F to close the picker and show the definition and source file.
Press Enter to put the selected function name at the shell prompt.
Add the necessary arguments before you run the command.

Use gfn without search text to show all Git functions.
Use gfn --list old to print the matches without the picker.
Use fn to search all function groups.'

# =========================
# Git diff helpers (gd*)
# =========================

# ---------- gdf: list files changed from HEAD~N to HEAD ----------
# Usage:
#   gdf       # == git diff --name-only HEAD~1 HEAD
#   gdf 2     # == git diff --name-only HEAD~2 HEAD
#   gdf 7     # == git diff --name-only HEAD~7 HEAD
gdf() {
  local n="${1:-1}"

  # numeric guard
  case "$n" in
    ''|*[!0-9]*)
      echo "Usage: gdf [number]" >&2
      return 1
      ;;
  esac

  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Not a git repo" >&2; return 1; }

  git diff --name-only "HEAD~${n}" HEAD
}

_ad_register gdf git/diff 'gdf [NUMBER]' 'List recent commit files; Compare HEAD with an earlier commit and list file names with net changes.' view gbdiff \
    'When: You need file names with net changes across the last three commits.
The branch must have enough history for HEAD~3 to exist.
Example:
  gdf 3
Result: The function compares HEAD~3 with HEAD and lists changed file names.
HEAD~3 follows the first parent three times from the current commit.
The list excludes changes that later commits fully reversed.
It also excludes uncommitted changes.
Use gdf without a number to compare HEAD~1 with HEAD.'
