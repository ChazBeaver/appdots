# =========================
# Multi-repository helpers (gr*)
# =========================

# Git Add All; Git Commit; Git Push for all child repos
grc() {
  local msg="$*"

  if [[ -z "$msg" ]]; then
    echo "❌ Usage: grc \"commit message\""
    return 1
  fi

  for d in */; do
    (
      cd "$d" || exit

      if [[ -d .git ]]; then
        echo "🚀 [$d] committing..."
        git aa && git com "$msg" && gps
      else
        echo "⏭️ [$d] skipped (not a git repo)"
      fi
    )
  done
}

_ad_register grc git/repos 'grc "COMMIT MESSAGE"' 'Stage, commit, and push every child Git repository.' danger 'dirgcm gcmdir'

# Git Rebase for all child repos
grr() {
  emulate -L zsh
  setopt local_options null_glob

  local parent="${1:-$PWD}"
  local dir name branch
  local -i ok=0 fail=0 skip=0

  for dir in "$parent"/*(N/); do
    name="${dir:t}"
    if [[ ! -d "$dir/.git" ]] && ! git -C "$dir" rev-parse --git-dir &>/dev/null; then
      print -P "%F{yellow}⊘ $name%f (not a git repo)"
      (( skip++ ))
      continue
    fi

    print -P "%F{cyan}▶ $name%f"
    branch=$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null)

    if [[ -z "$branch" ]]; then
      print -P "  %F{yellow}detached HEAD, fetching only%f"
      if git -C "$dir" fetch --all --prune --tags; then
        (( ok++ ))
      else
        (( fail++ ))
      fi
      continue
    fi

    if git -C "$dir" fetch --prune --tags origin && \
       git -C "$dir" pull --rebase --autostash origin "$branch"; then
      (( ok++ ))
    else
      print -P "  %F{red}✗ rebase failed (conflicts or other error — check repo state)%f"
      (( fail++ ))
    fi
  done

  print -P "\n%F{green}✓ $ok%f rebased  %F{red}✗ $fail%f failed  %F{yellow}⊘ $skip%f skipped"
}

_ad_register grr git/repos 'grr [DIRECTORY]' 'Fetch and rebase-autostash every child Git repository.' danger 'dirgpullr'

# Git Pull for all child repos
grp() {
  emulate -L zsh
  setopt local_options null_glob

  local parent="${1:-$PWD}"
  local dir name branch
  local -i ok=0 fail=0 skip=0

  for dir in "$parent"/*(N/); do
    name="${dir:t}"
    if [[ ! -d "$dir/.git" ]] && ! git -C "$dir" rev-parse --git-dir &>/dev/null; then
      print -P "%F{yellow}⊘ $name%f (not a git repo)"
      (( skip++ ))
      continue
    fi

    print -P "%F{cyan}▶ $name%f"
    branch=$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null)

    if [[ -z "$branch" ]]; then
      print -P "  %F{yellow}detached HEAD, fetching only%f"
      if git -C "$dir" fetch --all --prune --tags; then
        (( ok++ ))
      else
        (( fail++ ))
      fi
      continue
    fi

    if git -C "$dir" fetch --prune --tags origin && \
       git -C "$dir" pull --ff-only --no-rebase origin "$branch"; then
      (( ok++ ))
    else
      print -P "  %F{red}✗ pull failed (uncommitted changes, conflicts, or non-ff)%f"
      (( fail++ ))
    fi
  done

  print -P "\n%F{green}✓ $ok%f updated  %F{red}✗ $fail%f failed  %F{yellow}⊘ $skip%f skipped"
}

_ad_register grp git/repos 'grp [DIRECTORY]' 'Fetch and fast-forward every child Git repository.' danger 'dirgpull'

# Git Repo Status Audit
grs() {
  local root="${1:-.}"
  local green=$'\e[32m'
  local red=$'\e[31m'
  local reset=$'\e[0m'
  local repo name repo_status

  for repo in "$root"/*; do
    [[ -d "$repo" ]] || continue
    git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 || continue

    name="${repo:t}"
    repo_status="$(git -C "$repo" status --porcelain 2>/dev/null)"

    if [[ -n "$repo_status" ]]; then
      printf "%-22s %b\n" "$name" "${red}changes${reset}"
    else
      printf "%-22s %b\n" "$name" "${green}clean${reset}"
    fi
  done
}

_ad_register grs git/repos 'grs [DIRECTORY]' 'Show clean or changed status for child Git repositories.' view 'gbra'

# =========================
# Single-repository sync helpers (g*)
# =========================

# Git stash current work, pull updates, stash pop work back in place
gsp() {
  local message="stashing to pull latest"

  echo "🔒 Stashing current changes..."
  git stash push -m "$message" || return

  echo "⬇️  Pulling latest changes from remote..."
  git pull || {
    echo "❌ git pull failed. Keeping stash in place."
    return 1
  }

  echo "🔓 Re-applying stashed changes..."
  git stash pop || {
    echo "⚠️  git stash pop failed — resolve any conflicts manually."
    return 1
  }

  echo "✅ Done: pulled latest and reapplied your changes."
}

_ad_register gsp git/sync 'gsp' 'Stash current work, pull, and reapply the stash.' run 'stashpull'

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
  git merge origin/main

  echo "✅ Merge complete. '$branch' now includes 'origin/main'."
}

_ad_register gmm git/sync 'gmm' 'Fetch origin and merge origin/main into the current branch.' run 'mm'

# =========================
# Git Push/Pull helpers
# =========================

# Git Push Origin Upstream (unchanged)
gps() {
  local branch
  branch=$(git symbolic-ref --short HEAD 2>/dev/null)

  if [ -z "$branch" ]; then
    echo "❌ Not on a Git branch or not a Git repository."
    return 1
  fi

  echo "🚀 Pushing '$branch' to origin with upstream tracking..."
  git push -u origin "$branch"
}

_ad_register gps git/sync 'gps' 'Push the current branch to origin and set its upstream.' run 'gpush'

# Git Pull Origin (same spirit as gps)
# - pulls origin/<current-branch>
# - does NOT set upstream (pull doesn't need -u; upstream is set by gps)
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

_ad_register gpl git/sync 'gpl' 'Pull origin/current-branch into the current branch.' run 'gpull'

# =========================
# Git branch helpers (gb*)
# =========================

# ---------- gbh: searchable branch help ----------
gbh() {
  fn --group git/branch "$@"
}

_ad_register gbh help 'gbh [QUERY]' 'Browse the Git branch function family.' view

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

_ad_register gdf git/diff 'gdf [NUMBER]' 'List files changed between HEAD~NUMBER and HEAD.' view 'gbdiff'

# =========================
# Git branch operations (gb*)
# =========================

# ---------- gbu: Checkout & Update branch from Origin ----------
gbu() {
  local branch="$1"
  [[ -z "$branch" ]] && { echo "Usage: gbu <branch>" >&2; return 1; }
  git checkout "$branch" && git pull origin "$branch"
}

_ad_register gbu git/branch 'gbu BRANCH' 'Check out a branch and pull its matching branch from origin.' run

gbo() {
  # List remote-tracking branches whose last commit is older than 30 days (macOS),
  # excluding */HEAD and */main.
  #
  # Examples:
  #   gbo
  #   gbo | wc -l
  #   gbo | pbcopy

  # Refresh remotes quietly first
  git fetch --all --prune --quiet || return 1

  local cutoff
  cutoff="$(date -v-30d +%s)"

  git for-each-ref --format='%(refname:short) %(committerdate:unix)' refs/remotes \
  | while read -r branch ts; do
      case "$branch" in
        */HEAD|*/main) continue ;;
      esac

      if [ "$ts" -lt "$cutoff" ]; then
        printf "%-45s %s\n" "$branch" "$(date -r "$ts")"
      fi
    done \
  | sort
}

_ad_register gbo git/branch 'gbo' 'List remote branches whose latest commit is older than 30 days.' run 'gbls'

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

_ad_register gbl git/branch 'gbl [REPOSITORY]' 'List local and origin branches for a repository.' view

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
      | fzf --prompt="switch> "
  )" || return

  [[ -z "$selection" ]] && return

  if [[ "$selection" == origin/* ]]; then
    local_branch="${selection#origin/}"
    cmd="git -C \"$repo\" switch -c \"$local_branch\" --track \"$selection\""
  else
    cmd="git -C \"$repo\" switch \"$selection\""
  fi

  print -z -- "$cmd"
}

_ad_register gbs git/branch 'gbs [REPOSITORY]' 'Choose a branch and insert its Git switch command into the prompt.' view

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

_ad_register gbv git/branch 'gbv [BASE]' 'List current-branch file changes versus a base branch.' view 'gbcvm'

# ---------- gbp: prune remote-tracking branches (safe hygiene) ----------
gbp() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Not a git repo" >&2; return 1; }

  echo "== fetch/prune =="
  git fetch --all --prune || return 1

  echo
  echo "== upstream gone (local branches tracking deleted remote) =="
  git branch -vv | awk '/: gone]/{print $1}'

  echo
  echo "Tip: run 'gbd' to select and stage delete commands for dead branches."
}

_ad_register gbp git/branch 'gbp' 'Fetch and prune remotes, then list branches whose upstream is gone.' run

# ---------- gbr: report branch status (read-only; better categories) ----------
gbr() {
  local base
  base="$(_ad_gb_base "$1")"

  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Not a git repo" >&2; return 1; }

  echo "== fetch/prune (safe) =="
  git fetch --all --prune --quiet || return 1

  echo
  echo "== Active local (NOT merged into ${base}) =="
  git branch --no-merged "$base" 2>/dev/null | sed 's/^* //'

  echo
  echo "== Merged local (delete candidates) =="
  git branch --merged "$base" 2>/dev/null \
    | sed 's/^* //' \
    | grep -vE "^(${base}|main|master|develop)$"

  echo
  echo "== Upstream gone (tracks deleted remote) =="
  git branch -vv | awk '/: gone]/{print $1}'
}

_ad_register gbr git/branch 'gbr [BASE]' 'Report active, merged, and upstream-gone local branches.' view

# ---------- gbd: pick dead branches -> insert delete cmd (does not execute) ----------
gbd() {
  local base selection merged_list gone_list cmd

  unalias gbd 2>/dev/null
  command -v fzf >/dev/null 2>&1 || { echo "fzf not found in PATH" >&2; return 1; }
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Not a git repo" >&2; return 1; }

  base="$(_ad_gb_base "$1")"
  git fetch --all --prune --quiet || return 1

  merged_list="$(
    git branch --merged "$base" 2>/dev/null \
      | sed 's/^* //' \
      | grep -vE "^(${base}|main|master|develop)$"
  )"

  gone_list="$(git branch -vv | awk '/: gone]/{print $1}')"

  if [[ -z "$merged_list" && -z "$gone_list" ]]; then
    echo "No dead branches found (none merged into '$base' and none with upstream gone)."
    return 0
  fi

  selection="$(
    {
      [[ -n "$merged_list" ]] && printf "%s\n" "$merged_list" | sed 's/^/merged\t/'
      [[ -n "$gone_list" ]]   && printf "%s\n" "$gone_list"   | sed 's/^/gone\t/'
    } | fzf --prompt="delete> " --multi --with-nth=2.. --delimiter=$'\t'
  )" || return

  [[ -z "$selection" ]] && return

  cmd=""

  merged_list="$(printf "%s\n" "$selection" | awk -F'\t' '$1=="merged"{print $2}')"
  gone_list="$(printf "%s\n" "$selection"   | awk -F'\t' '$1=="gone"{print $2}')"

  if [[ -n "$merged_list" ]]; then
    cmd+="git branch -d"
    while IFS= read -r b; do
      [[ -n "$b" ]] && cmd+=" \"$b\""
    done <<< "$merged_list"
  fi

  if [[ -n "$gone_list" ]]; then
    [[ -n "$cmd" ]] && cmd+=" && "
    cmd+="git branch -D"
    while IFS= read -r b; do
      [[ -n "$b" ]] && cmd+=" \"$b\""
    done <<< "$gone_list"
  fi

  print -z -- "$cmd"
}

_ad_register gbd git/branch 'gbd [BASE]' 'Choose dead branches and insert their deletion command into the prompt.' danger
