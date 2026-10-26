# Installed personal repository workflows, selected by ~/.dotfiles-env.sh.
# Uses git-core.sh for shared checkout safeguards and summaries.

# Installed personal repositories are declared by their installers, not by
# the current shell's inherited variables or a fixed list of checkout names.
# Source fresh values in a subshell so aliases/exports do not affect the caller.
_ad_home_repos() (
  emulate -L zsh
  local action="$1"
  case "$action" in pull|sync|doctor|status) ;; *) return 1 ;; esac
  local env_file="${APPDOTS_ENV_FILE:-$HOME/.dotfiles-env.sh}"
  local line name dir script
  local -a repo_names match
  local -A seen
  local -i mbegin mend ok=0 failed=0 skipped=0 result
  [[ -r "$env_file" ]] || {
    print -u2 -r -- "Cannot read repository registry: $env_file"
    return 1
  }
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ '^[[:space:]]*export[[:space:]]+([A-Za-z_][A-Za-z0-9_]*_DIR)=' ]]; then
      repo_names+=("${match[1]}")
    fi
  done < "$env_file"
  (( ${#repo_names} )) || {
    print -u2 -r -- "No exported repository paths (*_DIR) in $env_file"
    return 1
  }
  source "$env_file" || {
    print -u2 -r -- "Cannot load repository registry: $env_file"
    return 1
  }
  for name in "${repo_names[@]}"; do
    dir="${(P)name}"
    if [[ -z "$dir" || ! -d "$dir" || ! -e "$dir/.git" ]]; then
      print -r -- "Skipping $name: ${dir:-<empty>} (missing Git checkout)."
      (( ++skipped ))
      continue
    fi
    dir="${dir:A}"
    [[ -z "${seen[$dir]:-}" ]] || continue
    seen[$dir]=1
    print -r -- "[$name: $dir]"
    if [[ "$action" == status ]]; then
      if git --no-optional-locks -C "$dir" status --short --branch --ahead-behind; then
        (( ++ok ))
      else
        print -u2 -r -- "Status failed: $dir"
        (( ++failed ))
      fi
      continue
    fi
    if [[ "$action" != pull ]]; then
      script="./$action.sh"
      if [[ ! -f "$dir/$action.sh" ]]; then
        print -r -- "Skipping $dir: no $script."
        (( ++skipped ))
      elif [[ ! -x "$dir/$action.sh" ]]; then
        print -u2 -r -- "Cannot run $script in $dir: script is not executable."
        (( ++failed ))
      elif (builtin cd -- "$dir" && "$script"); then
        (( ++ok ))
      else
        result=$?
        print -u2 -r -- "Failed: $script in $dir (exit $result)."
        (( ++failed ))
      fi
      continue
    fi
    if ! _ad_gb_clean "$dir"; then
      (( ++failed ))
      continue
    fi
    if ! git -C "$dir" symbolic-ref --quiet HEAD >/dev/null; then
      print -u2 -r -- "Detached HEAD: $dir. Switch to a branch before updating."
      (( ++failed ))
      continue
    fi
    if git -C "$dir" -c merge.autoStash=false pull --ff-only --no-rebase --no-autostash; then
      (( ++ok ))
    else
      print -u2 -r -- "Update failed: $dir. Inspect git status and the branch upstream."
      (( ++failed ))
    fi
  done
  _ad_gr_summary "home-$action" "$ok" "$failed" "$skipped"
)

home-pull() {
  (( $# == 0 )) || { print -u2 -- 'Usage: home-pull'; return 1; }
  _ad_home_repos pull
}
_ad_register home-pull git/repos home-pull 'Pull personal repos; Read ~/.dotfiles-env.sh and fast-forward each clean checkout from its configured upstream.' run 'hp repos-update' \
    'When: You want updates from another machine in your installed personal repos.
Example:
  home-pull
Result: The function reads exported *_DIR paths from ~/.dotfiles-env.sh.
Personal repositories live under ~/Projects/home; hp is the short alias.
It updates each checkout once, using the current branch and its upstream.
Only fast-forward pulls are allowed; local commits are never rebased.
Missing checkouts are skipped, and other failures do not stop later updates.
Dirty checkouts, detached HEADs, and unfinished Git operations need attention.
The final summary counts successes, failures, and missing checkouts.
The command returns nonzero if any checkout failed or could not be updated.
It does not run repository installers or sync scripts.
Zsh startup only defines the function; run it explicitly to update.'

home-status() {
  (( $# == 0 )) || { print -u2 -- 'Usage: home-status'; return 1; }
  _ad_home_repos status
}
_ad_register home-status git/repos home-status 'Check personal Git status; Show branch, upstream, ahead/behind counts, and file changes in installed repos without fetching.' view ht \
    'When: You want to see local work and cached remote status across repos.
Example:
  home-status
Result: The function reads installed repos from ~/.dotfiles-env.sh.
It prints git status --short --branch --ahead-behind for each checkout.
Use ht as the short alias.
The ## line shows the branch, upstream, and available ahead/behind counts.
Following lines list staged, unstaged, and untracked file changes.
A branch line without file entries means the checkout is clean.
Ahead/behind counts use cached remote references; no fetch is performed.
Dirty or detached checkouts are reported successfully.
Missing checkouts are skipped, and errors do not stop later repositories.
The final summary counts successful reports, failures, and skips.
It does not change files, refresh the index, or create directories.'

home-sync() {
  (( $# == 0 )) || { print -u2 -- 'Usage: home-sync'; return 1; }
  _ad_home_repos sync
}
_ad_register home-sync projects home-sync 'Sync personal repos; Run ./sync.sh in each installed checkout, continuing after failures.' run hs \
    'When: You have reviewed configuration changes and want to apply them.
Example:
  home-sync
Result: The function reads installed repos from ~/.dotfiles-env.sh.
It runs ./sync.sh in each checkout, once per path, in registry order.
Use hs as the short alias.
Sync applies the checked-out files, including uncommitted changes.
Each script controls its own effects, including links and desktop reloads.
Missing checkouts or scripts are skipped; a non-executable script fails.
Failures do not stop later repositories, and any failure returns nonzero.
The final summary counts successes, failures, and skips.
It does not pull repositories or substitute install.sh for a missing sync.'

home-doctor() {
  (( $# == 0 )) || { print -u2 -- 'Usage: home-doctor'; return 1; }
  _ad_home_repos doctor
}
_ad_register home-doctor projects home-doctor 'Check personal repos; Run ./doctor.sh in each installed checkout, continuing after failures.' view hd \
    'When: You want to check installed configuration across personal repos.
Example:
  home-doctor
Result: The function reads installed repos from ~/.dotfiles-env.sh.
It runs ./doctor.sh in each checkout, once per path, in registry order.
Use hd as the short alias.
Doctors check the installed machine, including links and declared packages.
Missing checkouts or scripts are skipped; a non-executable script fails.
Every available doctor runs even when an earlier one reports drift.
The final summary counts successes, failures, and skips.
Any failed doctor makes the command return nonzero.
It does not pull repositories or run sync scripts.'
