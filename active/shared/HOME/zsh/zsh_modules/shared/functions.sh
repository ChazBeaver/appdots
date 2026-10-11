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

_ad_register home projects home 'Choose a home project; Select a directory directly below ~/Projects/home and change to it.' run '' \
    'When: You need to change to a project in ~/Projects/home.
The directory ~/Projects/home/appdots must exist for this example.
Example:
  home
Result: The fzf picker lists directories directly in ~/Projects/home.
The list excludes hidden directories.
Type part of a directory name to reduce the list.
Select appdots with the arrow keys.
Press Enter to change to ~/Projects/home/appdots.
The function uses ~/Projects/home as a fixed path.'

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

_ad_register cx apps cx 'Open Codex in ~/.codex; Start Codex from its configuration directory, then return to the original directory.' run '' \
    'When: You need to start Codex from its configuration directory.
The directory ~/.codex must exist.
Example:
  cx
Result: The function records the current directory.
It changes to ~/.codex and starts Codex there.
When Codex stops, the shell returns to the recorded directory.
Use cx without arguments.'

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

_ad_register reporoot projects reporoot 'Go to the project directory; Change to the first directory below ~/Projects/home or ~/Projects/work.' run rr \
    'When: You are in ~/Projects/home/example/src.
You need to change to the top directory of that project.
Example:
  reporoot
Result: The shell changes to ~/Projects/home/example.
The function uses the first directory after ~/Projects/home/ in the path.
It also accepts paths below ~/Projects/work/.
It uses the directory path to find the project, without a Git command.
If you are outside these two project paths, the function shows an error.'

edit-zshrc() {
    vim $HOME/.zshrc
}

_ad_register edit-zshrc utilities edit-zshrc 'Edit Zsh startup configuration; Open ~/.zshrc with vim, which appdots maps to Neovim.' run '' \
    'When: You need to change the Zsh startup configuration in ~/.zshrc.
Example:
  edit-zshrc
Result: The function opens ~/.zshrc with vim.
In the managed shell, the vim alias selects Neovim.
Make the necessary changes in the editor.
Save the file with :w.
Close the editor with :q.
Open a new terminal session to use the new startup configuration.'

# Make a Dir and Jump to it Immediately
mkcd() {
  mkdir -p "$1" && cd "$1"
}

_ad_register mkcd projects 'mkcd DIRECTORY' 'Make and enter a directory; Create any missing parent directories, then change to the supplied path.' run '' \
    'When: You need to make a directory and change to it.
Example:
  mkcd ~/Projects/example
Result: The function makes ~/Projects/example if it does not exist.
It also makes the necessary parent directories.
The shell then changes to that directory.
If the directory already exists, the shell changes to it.
If mkdir fails, the shell stays in the original directory.
Use quotes for a path with spaces, for example: mkcd "example project".'

# Search History using FZF
fh() {
  local cmd
  cmd=$(fc -lnr 1 | fzf --tac) || return
  print -z -- "$cmd"
}

_ad_register fh fzf fh 'Find a history command; Search the current shell history and put the selected command at the prompt.' view hf \
    'When: You need to find a command in the history of the current shell.
Example:
  fh
Result: The function reads the shell history and opens the fzf picker.
Type part of the command to reduce the list.
Select a command with the arrow keys.
Press Enter to put the selected command at the shell prompt.
Check the command before you run it.

Press Ctrl-Y to copy the selected command to the clipboard.
The picker stays open after the copy.
Press Esc to close the picker without a selection.'

# Yazi launch and Change Directory when closed
y() {
  tmp="$(mktemp -t yazi-cwd.XXXXXX)"
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(cat "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    cd "$cwd"
  fi
  rm -f "$tmp"
}

_ad_register y apps 'y [PATH]' 'Browse and change directory; Open Yazi and change the shell to the final directory that Yazi reports.' run '' \
    'When: You need to use Yazi to select the next directory for the shell.
Example:
  y ~/Downloads
Result: The function opens Yazi at ~/Downloads.
Use Yazi to change to the necessary directory.
Close Yazi when you are ready to return to the shell.
The function reads the final directory path from Yazi.
The shell then changes to that directory.
Use y without a path to start in the current directory.'

# Print a list of Colors for testing
printcolors() {
  for i in {0..255}; do print -P "%F{$i}Color $i%f"; done
}

_ad_register printcolors utilities printcolors 'Show terminal colors; Print color numbers from 0 through 255 in their corresponding text colors.' view '' \
    'When: You need a color number for terminal text.
Example:
  printcolors
Result: The function prints color numbers from 0 to 255.
Each line uses the color that its number identifies.
Find the necessary color in the output.
Use its number in a terminal setting that accepts a color number.
The terminal theme can change the colors that these numbers show.'
