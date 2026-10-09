# Remove retired definitions when this module is reloaded in an existing shell.
# Former names remain searchable in their replacement's registry entry.
for _ad_retired_git_name in gps gbm gml gwc gwo; do
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
_ad_register grc git/repos 'grc [DIRECTORY] "COMMIT MESSAGE"' 'Commit/push child repos; stage changes and report failures.' danger 'dirgcm gcmdir' \
    'When: You checked the changes in the foo and bar repositories.
You want to publish them.
Example:
  grc ~/Projects/example "chore: update examples"
Result: The function adds all files in each direct child Git repository.
It makes a commit when files changed. It pushes each current branch to origin.
The function uses the same message for each new commit.'

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
_ad_register grr git/repos 'grr [DIRECTORY]' 'Rebase/pull child repos; fetch with autostash and report failures.' danger dirgpullr \
    'When: The foo and bar repositories have local commits and remote updates.
Example:
  grr ~/Projects/example
Result: The function fetches each direct child Git repository.
It rebases local commits on the matching branch at origin.
It uses autostash for tracked file changes.
If the pull succeeds, Git restores those changes.'

grp() {
  (( $# <= 1 )) || { print -u2 -- 'Usage: grp [DIRECTORY]'; return 1; }
  _ad_gr_pull fast-forward "${1:-$PWD}"
}
_ad_register grp git/repos 'grp [DIRECTORY]' 'Pull child repos; fetch with fast-forward only and report failures.' danger dirgpull \
    'When: You want remote updates in the foo and bar repositories.
Example:
  grp ~/Projects/example
Result: The function fetches each direct child Git repository.
It pulls the matching branch only when Git can fast-forward.
It reports a failure for a branch that has diverged.'

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
_ad_register grs git/repos 'grs [DIRECTORY]' 'Status of child repos; clean, changed, or failed.' view gbra \
    'When: You want to find local file changes in the foo and bar repositories.
Example:
  grs ~/Projects/example
Result: The function checks each direct child Git repository.
It shows clean, changed, or failed for each repository.
It does not fetch or change files.'

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

_ad_register gsp git/sync gsp 'Stash, pull, restore; reapply stashed changes.' run stashpull \
    'When: You changed tracked files and must pull before you commit them.
Example:
  gsp
Result: The function stashes tracked changes. It pulls the current branch.
It then restores the stash that it made. It does not stash untracked files.'

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

_ad_register gmm git/merge gmm 'Merge remote main in; fetch origin/main into this branch.' run mm \
    'When: You are on feature/foo. You want the latest origin/main in your branch.
Example:
  gmm
Result: The function fetches origin and merges origin/main into feature/foo.
It does not switch branches or push. Use gmi for your local main branch.'

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

_ad_register gpp git/sync gpp 'Push branch to origin; set upstream tracking.' run 'gps gpush' \
    'When: You are on feature/foo. You committed changes and want to publish them.
Example:
  gpp
Result: The function pushes feature/foo to origin/feature/foo.
It sets origin/feature/foo as the upstream branch. It does not commit files.'

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

_ad_register gpl git/sync gpl 'Pull current branch; pull origin/current-branch into this branch.' run gpull \
    'When: You are on feature/foo. That same branch has new commits at origin.
Example:
  gpl
Result: The function pulls origin/feature/foo into your current branch.
Git uses your pull settings to merge or rebase the commits.
Use gmm when you want origin/main.'

# =========================
# Git branch helpers (gb*)
# =========================

# ---------- gfh: searchable Git function help ----------
gfh() {
  local _AD_FN_CONTEXT_EXACT=1

  fn --group git "$@"
}

_ad_register gfh git/help 'gfh [--list] [QUERY]' 'Search Git helpers; branch, merge, diff, and cleanup.' view gbh \
    'When: You know what you want to do, but you do not know the command name.
Example:
  gfh old
Result: The picker shows Git helpers for old or stale branches.
Press Ctrl-E for an example. Press Ctrl-F for the function source.'

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

_ad_register gdf git/diff 'gdf [NUMBER]' 'Diff recent commit files; files changed across commits on this branch.' view gbdiff \
    'When: You want the names of files that changed in the last three commits.
Example:
  gdf 3
Result: The function compares HEAD~3 with HEAD and lists changed file names.
The example needs three earlier commits. Uncommitted changes are not included.'

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
_ad_register gbc git/branch 'gbc BRANCH [BASE]' 'Create branch from main; switch to a local branch with clean files.' run '' \
    'When: You want a new branch for a task. Your current checkout is clean.
Example:
  gbc feature/foo main
Result: The function creates feature/foo from local main.
It switches the current checkout to feature/foo. It does not make a worktree.'

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
_ad_register gbi git/branch 'gbi [BRANCH] [BASE]' 'Review branch commits/diff; inspect changes against local main.' view '' \
    'When: You finished work on feature/foo. You want to review it before a merge.
Example:
  gbi feature/foo main
Result: The function shows commits in feature/foo.
These commits are absent from local main.
It shows a summary and full diff from the common ancestor.
It does not include uncommitted changes.'

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
_ad_register gmo git/merge 'gmo [BRANCH] [TARGET]' 'Merge branch out to main; merge into the local target worktree, no push.' run gbm \
    'When: You tested feature/foo. You want its commits in local main.
Example:
  gmo feature/foo main
Result: The function merges feature/foo into local main.
It uses the worktree for main if one is open.
It does not push or delete feature/foo.
Commit changes in the affected checkouts before you use this command.'

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
_ad_register gmi git/merge 'gmi [BASE]' 'Merge local main in; merge into this branch, no fetch or pull.' run gml \
    'When: You are on feature/foo. Local main has new commits that you need.
Your checkout is clean.
Example:
  gmi main
Result: The function merges local main into feature/foo.
It does not fetch or push. Use gmm for the latest origin/main.'

# ---------- gbu: Checkout & Update branch from Origin ----------
gbu() {
  local branch="$1"
  [[ -z "$branch" ]] && { echo "Usage: gbu <branch>" >&2; return 1; }
  git checkout "$branch" && git pull origin "$branch"
}

_ad_register gbu git/branch 'gbu BRANCH' 'Switch/update branch; check out and pull matching branch from origin.' run '' \
    'When: You want to return to feature/foo and get its remote changes.
Example:
  gbu feature/foo
Result: The function checks out feature/foo.
It then pulls origin/feature/foo into that branch.
Use the existing worktree if feature/foo is open in another worktree.'

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

_ad_register gbo git/branch gbo 'Find old remote branches; older than 30 days, review stale branches.' run gbls \
    'When: You want to find old remote branches for review.
Example:
  gbo
Result: The function fetches and prunes remote references.
It lists remote branches whose last commit is older than 30 days.
It does not delete remote branches.'

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

_ad_register gbl git/branch 'gbl [REPOSITORY]' 'List local/remote branches; cached branch names, no fetch.' view '' \
    'When: You need a branch name before you switch or merge.
Example:
  gbl .
Result: The function lists local branches and cached origin branches.
It does not fetch. The list can be out of date until you fetch.'

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

_ad_register gbs git/branch 'gbs [REPOSITORY]' 'Switch branch; pick a local/remote branch to insert into the prompt.' view '' \
    'When: You want to select a branch by name.
Example:
  gbs .
Result: The function shows local and remote branches in a picker.
Select a branch to put a Git switch command at your prompt.
Review the command and press Enter to run it.'

# ---------- gbv: branch vs main ----------
# Compare changes made in current branch to base (defaults to main/master)
# Shows which files differ (name + status) between base..HEAD, using origin/<base> if present.
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

_ad_register gbv git/branch 'gbv [BASE]' 'Diff branch files vs main; files changed since branching from main.' view gbcvm \
    'When: You are on feature/foo.
You want files changed since the branch left main.
Example:
  gbv main
Result: The function lists changed file names and status codes.
It compares feature/foo with cached origin/main, if that branch exists.
Otherwise, it uses local main. It does not fetch.'

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
_ad_register gbp git/branch gbp 'Prune old remote refs; remove stale refs, report dead upstream branches.' run '' \
    'When: Your remote branch list still shows branches that no longer exist.
Example:
  gbp
Result: The function fetches from remotes.
It removes references that no longer exist.
It lists local branches that lost their remote upstream branch.
It does not delete local branches.'

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
_ad_register gbr git/branch 'gbr [BASE]' 'Report old/stale branches; active, merged, and dead upstreams.' run '' \
    'When: You want to review branches before you remove old local branches.
Example:
  gbr main
Result: The function lists active and merged branches.
It also lists branches that lost their upstream.
It marks branches that are open in a worktree. It does not delete branches.'

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
_ad_register gbd git/branch 'gbd [BASE]' 'Delete old merged branches; remove dead/stale branches safely.' danger '' \
    'When: You merged feature/foo into main. Its worktree is closed.
You want to delete the old local branch.
Example:
  gbd main
Result: The picker shows merged local branches that are not open in worktrees.
Select feature/foo with Tab.
Press Enter to put a git branch -d command at your prompt.
Review the command and press Enter to run it.'
