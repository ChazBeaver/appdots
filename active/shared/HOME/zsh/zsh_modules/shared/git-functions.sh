# Remove retired definitions when this module is reloaded in an existing shell.
# Former names remain searchable in their replacement's registry entry.
for _ad_retired_git_name in gps gbm gml gwc gwo gfh; do
  unfunction "$_ad_retired_git_name" 2>/dev/null || true
  unset "_AD_FN_GROUP[$_ad_retired_git_name]" "_AD_FN_USAGE[$_ad_retired_git_name]" \
    "_AD_FN_DESCRIPTION[$_ad_retired_git_name]" "_AD_FN_EFFECT[$_ad_retired_git_name]" \
    "_AD_FN_LEGACY[$_ad_retired_git_name]" "_AD_FN_SOURCE[$_ad_retired_git_name]" \
    "_AD_FN_EXAMPLE[$_ad_retired_git_name]" "_AD_FN_OWNED[$_ad_retired_git_name]"
done
unset _ad_retired_git_name

# =========================
# Multi-repository helpers (gr*)
# Only direct children with their own .git directory/file are in scope.
# =========================
_ad_gr_parent() {
  if [[ ! -d "$1" ]]; then
    print -u2 -r -- "Not a directory: $1"
    return 1
  fi
  print -r -- "${1:A}"
}

_ad_gr_summary() {
  printf '%s: %s succeeded, %s failed, %s skipped\n' "$1" "$2" "$3" "$4"
  (( $3 == 0 ))
}

# Stage, commit when needed, then push. A clean checkout can still have
# unpushed commits, including a commit left behind by a previous push failure.
grc() {
  emulate -L zsh
  setopt null_glob
  local parent msg dir branch
  local -i ok=0 failed=0 skipped=0 diff_result
  case $# in
    1) parent="$PWD"; msg="$1" ;;
    2) parent="$1"; msg="$2" ;;
    *) print -u2 -- 'Usage: grc [DIRECTORY] "COMMIT MESSAGE"'; return 1 ;;
  esac
  [[ -n "$msg" ]] || { print -u2 -- 'Commit message cannot be empty.'; return 1; }
  parent="$(_ad_gr_parent "$parent")" || return 1
  print -r -- "Stage, commit and push direct child repositories under $parent"
  for dir in "$parent"/*(N/); do
    if [[ ! -e "$dir/.git" ]]; then
      (( ++skipped ))
      continue
    fi
    print -r -- "[$dir]"
    if (
      builtin cd -- "$dir" || exit 1
      _ad_git_idle "$PWD" || exit 1
      branch="$(git symbolic-ref --quiet --short HEAD)" || {
        print -u2 -- 'Cannot commit/push a detached HEAD.'; exit 1
      }
      git remote get-url origin >/dev/null || {
        print -u2 -- 'No origin remote; nothing staged or committed.'; exit 1
      }
      git add --all || exit 1
      if git diff --cached --quiet; then
        print -r -- 'No new changes; pushing existing commits.'
      else
        diff_result=$?
        (( diff_result == 1 )) || exit "$diff_result"
        git commit -m "$msg" || exit 1
      fi
      gpp
    ); then
      (( ++ok ))
    else
      print -u2 -r -- "Failed: $dir. Inspect git status; any staged changes or new commit remain there."
      (( ++failed ))
    fi
  done
  _ad_gr_summary grc "$ok" "$failed" "$skipped"
}
_ad_register grc git/repos 'grc [DIRECTORY] "COMMIT MESSAGE"' 'Commit and push child repos; Stage all changes in direct child repositories and report failures.' danger 'dirgcm gcmdir' \
    'When: You need to commit and publish changes in several repositories.
The foo and bar repositories are directly below ~/Projects/example.
Check all changes in those repositories before you run this command.
Example:
  grc ~/Projects/example "chore: update examples"
Result: The function stages all changes in each direct child Git repository.
This includes file additions, changes, and deletions that Git can stage.
It makes a commit if staged changes exist.
It uses the same message for each new commit.
It pushes each current branch to origin and sets its upstream.
A repository with no file changes still pushes its existing commits.

Omit DIRECTORY to use the current directory as the parent.
The function skips directories without their own .git entry.
It reports failures and continues with the other repositories.
If a push fails, the local commit remains available for another attempt.
Use git status in a failed repository to check its state.'

_ad_gr_pull() {
  emulate -L zsh
  setopt null_glob
  local strategy="$1" parent dir branch
  local -a pull_options
  local -i ok=0 failed=0 skipped=0
  parent="$(_ad_gr_parent "$2")" || return 1
  if [[ "$strategy" == rebase ]]; then
    pull_options=(--rebase --autostash)
  else
    pull_options=(--ff-only --no-rebase)
  fi
  print -r -- "Pull ($strategy) direct child repositories under $parent"
  for dir in "$parent"/*(N/); do
    if [[ ! -e "$dir/.git" ]]; then
      (( ++skipped ))
      continue
    fi
    print -r -- "[$dir]"
    if ! _ad_git_idle "$dir"; then
      (( ++failed ))
      continue
    fi
    if ! branch="$(git -C "$dir" symbolic-ref --quiet --short HEAD)"; then
      print -r -- 'Detached HEAD: fetching only, without changing the checkout.'
      if git -C "$dir" fetch --all --prune --tags; then
        (( ++ok ))
      else
        print -u2 -r -- "Fetch failed: $dir"
        (( ++failed ))
      fi
    elif git -C "$dir" fetch --prune --tags origin && \
         git -C "$dir" pull "${pull_options[@]}" origin "$branch"; then
      (( ++ok ))
    else
      print -u2 -r -- "Pull failed: $dir ($branch). Inspect git status there before retrying."
      (( ++failed ))
    fi
  done
  _ad_gr_summary "Pull ($strategy)" "$ok" "$failed" "$skipped"
}

grr() {
  (( $# <= 1 )) || { print -u2 -- 'Usage: grr [DIRECTORY]'; return 1; }
  _ad_gr_pull rebase "${1:-$PWD}"
}
_ad_register grr git/repos 'grr [DIRECTORY]' 'Rebase child repos from origin; Fetch and pull direct child repositories with rebase and autostash.' danger dirgpullr \
    'When: Several repositories have local commits and new commits at origin.
The repositories are directly below ~/Projects/example.
Example:
  grr ~/Projects/example
Result: The function fetches origin and prunes its stale references.
It rebases each current branch onto the branch with the same name at origin.
Git uses autostash to save and restore tracked file changes.
The rebase or the restoration of changes can cause conflicts.
For a detached HEAD, the function only fetches from all remotes.

Omit DIRECTORY to use the current directory as the parent.
The function reports failures and continues with the other repositories.
If a repository fails, check git status in that repository.
Resolve any conflicts before you retry the command.'

grp() {
  (( $# <= 1 )) || { print -u2 -- 'Usage: grp [DIRECTORY]'; return 1; }
  _ad_gr_pull fast-forward "${1:-$PWD}"
}
_ad_register grp git/repos 'grp [DIRECTORY]' 'Pull child repos from origin; Fetch direct child repositories and allow only fast-forward updates.' danger dirgpull \
    'When: You need remote updates in several repositories.
The repositories are directly below ~/Projects/example.
Example:
  grp ~/Projects/example
Result: The function fetches origin and prunes its stale references.
It pulls the branch with the same name as each current branch.
The pull permits only a fast-forward update.
If local and remote commits have diverged, the pull fails.
For a detached HEAD, the function only fetches from all remotes.

Omit DIRECTORY to use the current directory as the parent.
The function reports failures and continues with the other repositories.
If a repository fails, check git status in that repository.'

grs() {
  emulate -L zsh
  setopt null_glob
  (( $# <= 1 )) || { print -u2 -- 'Usage: grs [DIRECTORY]'; return 1; }
  local parent dir repo_status
  local -i ok=0 failed=0 skipped=0
  parent="$(_ad_gr_parent "${1:-$PWD}")" || return 1
  print -r -- "Status of direct child repositories under $parent"
  for dir in "$parent"/*(N/); do
    if [[ ! -e "$dir/.git" ]]; then
      (( ++skipped ))
      continue
    fi
    if repo_status="$(git -C "$dir" status --porcelain)"; then
      if [[ -n "$repo_status" ]]; then
        printf '%-22s changes\n' "${dir:t}"
      else
        printf '%-22s clean\n' "${dir:t}"
      fi
      (( ++ok ))
    else
      print -u2 -r -- "Status failed: $dir"
      (( ++failed ))
    fi
  done
  _ad_gr_summary grs "$ok" "$failed" "$skipped"
}
_ad_register grs git/repos 'grs [DIRECTORY]' 'Check child repository files; Report clean files, local changes, or failures in direct child repositories.' view gbra \
    'When: You need to find repositories with local file changes.
The repositories are directly below ~/Projects/example.
Example:
  grs ~/Projects/example
Result: The function checks each direct child Git repository.
It prints clean or changes for each successful check.
It reports failed checks and skips directories without their own .git entry.
The final summary gives the number of successful, failed, and skipped checks.
Omit DIRECTORY to use the current directory as the parent.
A clean result can still have commits that you have not pushed.'

# =========================
# Single-repository sync helpers (g*)
# =========================

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

# Git Merge Main into Feature-Branch
gmm() {
  # Get the current branch
  local branch
  branch=$(git symbolic-ref --short HEAD 2>/dev/null)

  if [ -z "$branch" ]; then
    echo "❌ Not on a Git branch or not in a Git repository."
    return 1
  fi

  echo "📍 Current branch: $branch"

  # Fetch latest from origin
  echo "🔄 Fetching latest changes from origin..."
  git fetch origin || return 1

  # Merge main into the current branch
  echo "📦 Merging origin/main into $branch..."
  git merge origin/main || {
    echo "❌ Merge failed. Resolve the Git error before continuing."
    return 1
  }

  echo "✅ Merge complete. '$branch' now includes 'origin/main'."
}

_ad_register gmm git/merge gmm 'Merge origin/main in; Fetch origin, then merge its main branch into the current branch.' run mm \
    'When: You are on feature/foo and need the latest commits from origin/main.
The remote origin must have a main branch.
Example:
  gmm
Result: The function fetches origin and merges origin/main into feature/foo.
The shell stays on feature/foo.
Git uses your merge settings for the merge.
If conflicts occur, use git status to identify the files that need changes.
Use gmi main when you need the commits from local main.
The function does not push the result.'

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

# =========================
# Git branch helpers (gb*)
# =========================

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

# ---------- internal helper: choose a sensible base branch ----------
_ad_gb_base() {
  local base="${1:-}"

  if [[ -n "$base" ]]; then
    print -r -- "$base"
    return 0
  fi

  if git show-ref --verify --quiet refs/heads/main; then
    print -r -- "main"; return 0
  fi
  if git show-ref --verify --quiet refs/heads/master; then
    print -r -- "master"; return 0
  fi

  git branch --show-current 2>/dev/null
}

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

# =========================
# Git branch operations (gb*)
# =========================

# Local workflows use refs/heads explicitly: no origin fallback or fetching.
_ad_gb_require_local() {
  git show-ref --verify --quiet "refs/heads/$1" && return 0
  print -u2 -r -- "Local branch not found: $1"
  return 1
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

# NUL-delimited records preserve spaces and other special characters in paths.
_ad_gb_worktree() {
  local entry checkout
  while IFS= read -r -d '' entry; do
    case "$entry" in
      'worktree '*) checkout="${entry#worktree }" ;;
      "branch refs/heads/$1") print -r -- "$checkout"; return 0 ;;
    esac
  done < <(git worktree list --porcelain -z)
}

_ad_gb_merge_local() {
  local dir="$1" source_branch="$2" target_branch="$3"
  _ad_gb_clean "$dir" || return 1
  if [[ "$(git -C "$dir" symbolic-ref --quiet --short HEAD)" != "$target_branch" ]]; then
    print -u2 -r -- "Expected $target_branch to be checked out in $dir."
    return 1
  fi
  print -r -- "Merging $source_branch into $target_branch in $dir"
  git -C "$dir" -c merge.autoStash=false merge --ff --no-edit \
    -m "chore: merge $source_branch into $target_branch" "refs/heads/$source_branch" || {
    print -u2 -r -- "Merge stopped in $dir. Inspect git status there; resolve and run git merge --continue, or git merge --abort."
    return 1
  }
}

# Create a topic from local main/master (or an explicit local base).
gbc() {
  emulate -L zsh
  if (( $# < 1 || $# > 2 )); then
    print -u2 -- 'Usage: gbc BRANCH [BASE]'
    return 1
  fi
  local branch="$1" base
  git check-ref-format --branch "$branch" >/dev/null || return 1
  base="$(_ad_gb_base "${2:-}")" || return 1
  _ad_gb_require_local "$base" && _ad_gb_clean "$PWD" || return 1
  git switch --no-track -c "$branch" "refs/heads/$base"
}
_ad_register gbc git/branch 'gbc BRANCH [BASE]' 'Create and switch branch; Create a branch from a local base without fetching or making a worktree.' run '' \
    'When: You need a new branch for a task, based on local main.
The checkout must have no tracked changes or untracked files.
Finish any Git operation in progress before you run this command.
Example:
  gbc feature/foo main
Result: The function creates feature/foo from local main.
It switches the current checkout to feature/foo.
The new branch has no upstream until you set one, for example with gpp.
The function needs main to exist locally and feature/foo to be a new name.
It does not fetch or create a separate worktree.

Without BASE, it uses local main, then master, then the current branch.
It uses the first available branch in that order.'

# Review committed topic changes without consulting origin.
gbi() {
  emulate -L zsh
  if (( $# > 2 )); then
    print -u2 -- 'Usage: gbi [BRANCH] [BASE]'
    return 1
  fi
  local branch="${1:-$(git symbolic-ref --quiet --short HEAD)}" base
  base="$(_ad_gb_base "${2:-}")" || return 1
  _ad_gb_require_local "$branch" && _ad_gb_require_local "$base" || return 1
  print -r -- "Commits in $branch not in local $base:"
  git --no-pager log --oneline "refs/heads/$base..refs/heads/$branch" || return 1
  git diff --stat --patch "refs/heads/$base...refs/heads/$branch"
}
_ad_register gbi git/branch 'gbi [BRANCH] [BASE]' 'Review branch commits and diff; Show committed changes against a local base without fetching.' view '' \
    'When: You need to review the committed work on feature/foo before a merge.
Both feature/foo and main must exist as local branches.
Example:
  gbi feature/foo main
Result: The function lists commits in feature/foo that are absent from main.
It also shows a file summary and the full diff.
The diff starts at the common ancestor of main and feature/foo.
The review excludes uncommitted changes.
The current checkout stays on its original branch.

Without BRANCH, it reviews the current branch.
Without BASE, it uses local main, then master, then the current branch.
Use gbi feature/foo develop to compare with a different local base.'

# Merge a topic into the target's existing worktree when it has one.
gmo() {
  emulate -L zsh
  if (( $# > 2 )); then
    print -u2 -- 'Usage: gmo [BRANCH] [TARGET]'
    return 1
  fi
  local branch="${1:-$(git symbolic-ref --quiet --short HEAD)}" target source_dir target_dir
  target="$(_ad_gb_base "${2:-}")" || return 1
  _ad_gb_require_local "$branch" && _ad_gb_require_local "$target" || return 1
  if [[ "$branch" == "$target" ]]; then
    print -u2 -- 'Specify a topic branch; source and target must differ.'
    return 1
  fi
  _ad_gb_clean "$PWD" || return 1
  source_dir="$(_ad_gb_worktree "$branch")"
  if [[ -n "$source_dir" ]]; then
    _ad_gb_clean "$source_dir" || return 1
  fi
  target_dir="$(_ad_gb_worktree "$target")"
  if [[ -z "$target_dir" ]]; then
    git switch --no-guess "$target" || return 1
    target_dir="$PWD"
  fi
  _ad_gb_merge_local "$target_dir" "$branch" "$target"
}
_ad_register gmo git/merge 'gmo [BRANCH] [TARGET]' 'Merge branch into local target; Use the target worktree when available, without fetching or pushing.' run gbm \
    'When: You tested feature/foo and need to merge its commits into local main.
The current, source, and target checkouts must have no file changes.
The checkouts must also have no untracked files.
Finish any Git operation in progress before you run this command.
Example:
  gmo feature/foo main
Result: The function merges feature/foo into local main.
If a worktree has main checked out, the merge runs in that worktree.
Otherwise, the current checkout switches to main before the merge.
Git uses a fast-forward when possible or makes a merge commit.
The source branch and its worktree remain available after the merge.
The function does not fetch or push.

Without BRANCH, it uses the current branch as the source.
Without TARGET, it uses local main, then master, then the current branch.
The source and target must be different local branches.
If the merge stops, check git status in the target worktree.'

# Local counterpart to gmm, which fetches and merges origin/main.
gmi() {
  emulate -L zsh
  if (( $# > 1 )); then
    print -u2 -- 'Usage: gmi [BASE]'
    return 1
  fi
  local branch base
  branch="$(git symbolic-ref --quiet --short HEAD)" || return 1
  base="$(_ad_gb_base "${1:-}")" || return 1
  _ad_gb_require_local "$base" || return 1
  if [[ "$branch" == "$base" ]]; then
    print -u2 -r -- "Already on $base; switch to a topic branch first."
    return 1
  fi
  _ad_gb_merge_local "$PWD" "$base" "$branch"
}
_ad_register gmi git/merge 'gmi [BASE]' 'Merge local base into branch; Merge a local branch into the current branch without fetching or pushing.' run gml \
    'When: You are on feature/foo and need new commits from local main.
The checkout must have no tracked changes or untracked files.
Finish any Git operation in progress before you run this command.
Example:
  gmi main
Result: The function merges local main into feature/foo.
Git uses a fast-forward when possible or makes a merge commit.
The shell stays on feature/foo.
If the merge stops, use git status to inspect the checkout.

Without BASE, it uses local main, then master, then the current branch.
The base must be a different local branch from the current branch.
Use gmm to fetch and merge origin/main.'

# ---------- gbu: Checkout & Update branch from Origin ----------
gbu() {
  local branch="$1"
  [[ -z "$branch" ]] && { echo "Usage: gbu <branch>" >&2; return 1; }
  git checkout "$branch" && git pull origin "$branch"
}

_ad_register gbu git/branch 'gbu BRANCH' 'Switch branch and pull; Check out a branch and pull the branch with the same name from origin.' run '' \
    'When: You need to switch to feature/foo and get its remote commits.
Example:
  gbu feature/foo
Result: The function checks out feature/foo.
It then pulls origin/feature/foo into that branch.
Git uses your pull settings to merge, rebase, or require a fast-forward.
If the checkout fails, the function stops before the pull.
A failed pull does not undo the branch switch.
Use its existing worktree if another worktree has feature/foo checked out.'

gbo() {
  emulate -L zsh
  setopt pipefail
  # List remote-tracking branches whose last commit is older than 30 days,
  # excluding */HEAD and */main.
  #
  # Examples:
  #   gbo
  #   gbo | wc -l
  #   gbo | pbcopy

  # Refresh remotes quietly first
  git fetch --all --prune --quiet || return 1

  zmodload zsh/datetime 2>/dev/null || {
    echo "Unable to load zsh/datetime" >&2
    return 1
  }

  local -i cutoff=$(( EPOCHSECONDS - 30 * 24 * 60 * 60 ))

  git for-each-ref --format='%(refname)%09%(committerdate:unix)%09%(committerdate:short)' refs/remotes \
  | while IFS=$'\t' read -r ref ts commit_date; do
      case "$ref" in
        refs/remotes/*/HEAD|refs/remotes/*/main) continue ;;
      esac

      if [ "$ts" -lt "$cutoff" ]; then
        local branch="${ref#refs/remotes/}"
        printf "%-45s %s\n" "$branch" "$commit_date"
      fi
    done \
  | sort
}

_ad_register gbo git/branch gbo 'Find old remote branches; Fetch all remotes and list branches whose tip commit is over 30 days old.' run gbls \
    'When: You need to find remote branches with old commits for review.
Example:
  gbo
Result: The function fetches from all remotes and prunes stale references.
It lists remote branches whose tip commit is older than 30 days.
Each row shows a branch name and its commit date.
It uses the committer date of the tip commit to calculate its age.
The list excludes the main branch and HEAD reference for each remote.
The function does not delete branches on the remotes.'

# ---------- gbl ----------
gbl() {
  local repo="${1:-$PWD}"

  if ! git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Not a git repo: $repo" >&2
    return 1
  fi

  echo "## Local branches"
  git -C "$repo" branch --format='%(refname:short)' | sed 's/^/  /'

  echo
  echo "## Remote branches (origin)"
  git -C "$repo" branch -r --format='%(refname:short)' \
    | grep -E '^origin/' \
    | grep -vE '^origin/HEAD$' \
    | sed 's/^/  /'
}

_ad_register gbl git/branch 'gbl [REPOSITORY]' 'List local and origin branches; Show cached branch names in the selected repository without fetching.' view '' \
    'When: You need a branch name before you switch or merge.
Example:
  gbl .
Result: The function lists local branches and cached origin branches.
The list excludes branches from other remotes.
It does not fetch, so the remote list can be out of date.
Without REPOSITORY, it uses the current directory.
Use gbl ~/Projects/home/appdots to inspect another repository.'

# ---------- gbs ----------
gbs() {
  local repo="${1:-$PWD}"
  local selection cmd local_branch

  unalias gbs 2>/dev/null

  command -v fzf >/dev/null 2>&1 || { echo "fzf not found in PATH" >&2; return 1; }
  git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Not a git repo: $repo" >&2; return 1; }

  selection="$(
    {
      git -C "$repo" branch --format='%(refname:short)'
      git -C "$repo" branch -r --format='%(refname:short)' \
        | grep -E '^origin/' \
        | grep -vE '^origin/HEAD$'
    } | awk 'NF && !seen[$0]++' \
      | fzf +m --prompt="switch> "
  )" || return

  [[ -z "$selection" ]] && return

  if [[ "$selection" == origin/* ]]; then
    local_branch="${selection#origin/}"
    cmd="git -C ${(q)repo} switch -c ${(q)local_branch} --track ${(q)selection}"
  else
    cmd="git -C ${(q)repo} switch ${(q)selection}"
  fi

  print -z -- "$cmd"
}

_ad_register gbs git/branch 'gbs [REPOSITORY]' 'Prepare a branch switch; Pick a local or origin branch and put a switch command at the prompt.' view '' \
    'When: You need to select a branch by name before you switch to it.
Example:
  gbs .
Result: The picker lists local branches and cached origin branches.
Select a branch with the arrow keys.
Press Enter to put a Git switch command at the shell prompt.
Check that command before you run it.

A local selection prepares a switch to the existing branch.
An origin selection prepares a new local branch that tracks the remote branch.
Select the local entry if that local branch already exists.
Without REPOSITORY, the function uses the current directory.
The function does not fetch, so the remote list can be out of date.'

# ---------- gbv: branch vs main ----------
# Compare changes made in current branch to base (defaults to main/master)
# Show committed file changes from the merge base, preferring origin/<base>.
gbv() {
  local base base_ref
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Not a git repo" >&2; return 1; }

  base="$(_ad_gb_base "$1")"

  # Prefer origin/<base> when it exists; otherwise fall back to local <base>
  if git show-ref --verify --quiet "refs/remotes/origin/${base}"; then
    base_ref="origin/${base}"
  else
    base_ref="${base}"
  fi

  git diff --name-status "${base_ref}...HEAD"
}

_ad_register gbv git/branch 'gbv [BASE]' 'List branch file changes; Diff committed file names and status codes from the common ancestor with a base.' view gbcvm \
    'When: You are on feature/foo and need its committed file changes.
Example:
  gbv main
Result: The function lists changed file names and status codes.
It uses cached origin/main if that reference exists, or local main otherwise.
The diff starts at the common ancestor of that reference and HEAD.
Status codes include A for added, M for modified, and D for deleted files.
The output excludes uncommitted changes.
The function does not fetch, so the remote reference can be out of date.

Without BASE, it selects a local name: main, master, then the current branch.
It prefers the matching origin reference for that name.
Use gbi to see the full diff against a local base.'

# Structured ref fields avoid the whitespace, '*' and '+' markers in branch -vv.
_ad_gb_gone() {
  git for-each-ref --format='%(refname:lstrip=2)%09%(upstream:track)' refs/heads \
    | awk -F '\t' '$2 == "[gone]" { print $1 }'
}

_ad_gb_protected() {
  case "$1" in
    "$2"|main|master|develop|trunk) return 0 ;;
    *) return 1 ;;
  esac
}

gbp() {
  emulate -L zsh
  setopt pipefail
  git rev-parse --git-dir >/dev/null 2>&1 || return 1
  print -r -- 'Fetch/prune old remote refs; report dead/stale upstream branches:'
  git fetch --all --prune || return 1
  _ad_gb_gone
}
_ad_register gbp git/branch gbp 'Prune old remote references; Fetch all remotes, prune stale references, and report missing upstreams.' run '' \
    'When: Your remote branch list still shows branches that no longer exist.
Example:
  gbp
Result: The function fetches from all remotes.
It removes local references to branches that no longer exist on the remotes.
It lists local branches whose configured upstream reference is missing.
A missing upstream does not mean that the local commits are merged.
The function keeps the local branches.'

gbr() {
  emulate -L zsh
  setopt pipefail
  local base branch records line
  local -a fields
  base="$(_ad_gb_base "${1:-}")" || return 1
  _ad_gb_require_local "$base" || return 1
  git fetch --all --prune --quiet || return 1
  print -r -- "Active branches not merged into $base:"
  git for-each-ref --no-merged="refs/heads/$base" --format='%(refname:lstrip=2)' refs/heads || return 1
  print -r -- "Old merged branches (checked-out worktrees are marked):"
  records="$(git for-each-ref --merged="refs/heads/$base" \
    --format='%(refname:lstrip=2)%09%(worktreepath)' refs/heads)" || return 1
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    fields=( "${(@ps:\t:)line}" )
    branch="$fields[1]"
    _ad_gb_protected "$branch" "$base" && continue
    if [[ -n "${fields[2]:-}" ]]; then
      print -r -- "$branch (checked out: $fields[2])"
    else
      print -r -- "$branch"
    fi
  done <<< "$records"
  print -r -- 'Dead/stale branches whose upstream is gone (may be unmerged):'
  _ad_gb_gone
}
_ad_register gbr git/branch 'gbr [BASE]' 'Report branch merge status; Fetch remotes and report active, old merged, and stale upstream branches.' run '' \
    'When: You need to review local branches before you remove them.
The base branch main must exist locally for this example.
Example:
  gbr main
Result: The function fetches from all remotes and prunes stale references.
It compares local branches with local main.
It lists unmerged branches, then branches merged into main.
The merged list excludes main, master, develop, trunk, and the selected base.
It marks merged branches that are checked out in a worktree.
It also lists local branches with missing upstream references.

The report uses merge status, without an age limit.
The fetch does not update local main to match origin/main.
Without BASE, it uses local main, then master, then the current branch.
The function does not delete branches.'

# Only merged, unchecked-out, unprotected branches are deletion candidates.
# A vanished upstream alone is not proof that local commits can be deleted.
_ad_gb_delete_candidates() {
  local base="$1" records line branch
  local -a fields
  records="$(git for-each-ref --merged="refs/heads/$base" \
    --format='%(refname:lstrip=2)%09%(worktreepath)' refs/heads)" || return 1
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    fields=( "${(@ps:\t:)line}" )
    branch="$fields[1]"
    _ad_gb_protected "$branch" "$base" && continue
    [[ -z "${fields[2]:-}" ]] || continue
    print -r -- "$branch"
  done <<< "$records"
}

gbd() {
  emulate -L zsh
  (( $# <= 1 )) || { print -u2 -- 'Usage: gbd [BASE]'; return 1; }
  command -v fzf >/dev/null 2>&1 || { print -u2 -- 'fzf not found'; return 1; }
  local base candidates selection branch cmd repo
  base="$(_ad_gb_base "${1:-}")" || return 1
  _ad_gb_require_local "$base" || return 1
  git fetch --all --prune --quiet || return 1
  candidates="$(_ad_gb_delete_candidates "$base")" || return 1
  if [[ -z "$candidates" ]]; then
    print -r -- "No old branches to delete: none merged into $base outside active worktrees."
    return 0
  fi
  selection="$(print -r -- "$candidates" | fzf --multi --prompt='delete old branches> ' \
    --header="Merged into $base only; Tab selects, Enter inserts, Esc cancels")" || return 0
  [[ -n "$selection" ]] || return 0
  # Prefer the base checkout so git branch -d checks the intended main HEAD.
  repo="$(_ad_gb_worktree "$base")"
  [[ -n "$repo" ]] || repo="$(git rev-parse --show-toplevel)" || return 1
  cmd="git -C ${(q)repo} branch -d --"
  while IFS= read -r branch; do
    [[ -n "$branch" ]] && cmd+=" ${(q)branch}"
  done <<< "$selection"
  print -z -- "$cmd"
}
_ad_register gbd git/branch 'gbd [BASE]' 'Prepare branch deletion; Select old merged local branches and put a delete command at the prompt.' danger '' \
    'When: You merged feature/foo into local main and need to delete that branch.
No worktree can have feature/foo checked out, even if its terminal is closed.
Example:
  gbd main
Result: The function fetches from all remotes and prunes stale references.
The picker lists local branches whose commits are all in local main.
It excludes branches checked out in any worktree.
It also excludes main, master, develop, trunk, and the selected base.
Local main must already contain the commits; a fetch does not update it.

Select feature/foo with Tab.
Press Enter to put a git branch -d command at your prompt.
Check that command before you run it.
The command uses the base worktree if one exists, or the current repository.
Git can refuse deletion if its additional merge checks fail.

Without BASE, it uses local main, then master, then the current branch.
A missing upstream alone does not make a branch eligible for deletion.'
