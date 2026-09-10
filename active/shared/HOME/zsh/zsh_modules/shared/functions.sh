# ---------- home: fzf jump into ~/Projects/home (names only) ----------
home () {
  local base="$HOME/Projects/home"
  local choice
  [[ -d "$base" ]] || {
    echo "❌ Missing: $base"
    return 1
  }

  choice="$(
    for d in "$base"/*; do
      [[ -d "$d" ]] && basename "$d"
    done \
      | sort \
      | fzf \
          --height 60% \
          --reverse \
          --prompt='home> ' \
          --preview 'ls -la --color=always "$HOME/Projects/home/{}" | sed -n "1,120p"'
  )" || return 0

  cd "$base/$choice" || return 1
}

_ad_register home projects 'home' 'Choose a repository under ~/Projects/home and change into it.' run

# work() {
#   local base="$HOME/Projects/work"
#   local choice
#
#   [[ -d "$base" ]] || { echo "❌ Missing: $base"; return 1; }
#
#   # Collect directories one and two levels below $base
#   choice="$(
#     {
#       # level 1: immediate children
#       find "$base" -mindepth 1 -maxdepth 1 -type d 2>/dev/null
#       # level 2: children of immediate children
#       find "$base" -mindepth 2 -maxdepth 2 -type d 2>/dev/null
#     } \
#       | sed "s|^$base/||" \
#       | sort \
#       | fzf \
#           --height 60% \
#           --reverse \
#           --prompt='work> ' \
#           --preview 'ls -la --color=always "$HOME/Projects/work/{}" | sed -n "1,120p"'
#   )" || return 0
#
#   cd "$base/$choice" || return 1
# }
#

cx() {
  local prev=$PWD
  cd ~/.codex && codex
  cd "$prev"
}

_ad_register cx apps 'cx' 'Launch Codex from ~/.codex, then return to the previous directory.' run

reporoot() {
  local dir="$PWD"
  dir="${dir%/}"

  local base_home="$HOME/Projects/home/"
  local base_work="$HOME/Projects/work/"

  # If we're somewhere under ~/Projects/home/<repo>/...
  if [[ "$dir" == "$base_home"* ]]; then
    local rest="${dir#"$base_home"}"   # everything after .../home/
    local top="${rest%%/*}"            # first path segment (repo name)
    [[ -n "$top" ]] || { echo "Already at $base_home"; return 1; }
    cd "$base_home$top" || return 1
    return 0
  fi

  # If we're somewhere under ~/Projects/work/<repo>/...
  if [[ "$dir" == "$base_work"* ]]; then
    local rest="${dir#"$base_work"}"   # everything after .../work/
    local top="${rest%%/*}"            # first path segment (repo name)
    [[ -n "$top" ]] || { echo "Already at $base_work"; return 1; }
    cd "$base_work$top" || return 1
    return 0
  fi

  echo "Not inside ~/Projects/home or ~/Projects/work"
  return 1
}

_ad_register reporoot projects 'reporoot' 'Change to the top-level project directory under Projects/home or Projects/work.' run 'rr'

edit-zshrc() {
    vim $HOME/.zshrc
}

_ad_register edit-zshrc utilities 'edit-zshrc' 'Open ~/.zshrc in Vim.' run

# Make a Dir and Jump to it Immediately
mkcd() {
  mkdir -p "$1" && cd "$1"
}

_ad_register mkcd projects 'mkcd DIRECTORY' 'Create a directory and immediately change into it.' run

# Search History using FZF
fh() {
  local cmd
  cmd=$(fc -lnr 1 | fzf --tac) || return
  print -z -- "$cmd"
}

_ad_register fh fzf 'fh' 'Choose a shell-history entry and insert it into the prompt.' view 'hf'

# Yazi launch and Change Directory when closed
y() {
  tmp="$(mktemp -t yazi-cwd.XXXXXX)"
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(cat "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    cd "$cwd"
  fi
  rm -f "$tmp"
}

_ad_register y apps 'y [PATH]' 'Launch Yazi and adopt its directory when it exits.' run

# Print a list of Colors for testing
printcolors() {
  for i in {0..255}; do print -P "%F{$i}Color $i%f"; done
}

_ad_register printcolors utilities 'printcolors' 'Print the terminal color palette from 0 through 255.' view
