# Bulk Git operations on direct child repositories of a directory.
# Uses git-core.sh for shared safeguards, summaries, and gpp.

_ad_gr_parent() {
  if [[ ! -d "$1" ]]; then
    print -u2 -r -- "Not a directory: $1"
    return 1
  fi
  print -r -- "${1:A}"
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
