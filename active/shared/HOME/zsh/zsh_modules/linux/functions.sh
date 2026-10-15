cam() {
  webcam-launch "${1:-overlay}"
}

_ad_register cam apps 'cam [MODE]' 'Open the webcam; Start webcam-launch with the supplied mode, or overlay by default.' run '' \
    'When: You need to open the webcam in overlay mode.
The external webcam-launch command must be available.
Example:
  cam
Result: The function runs webcam-launch with overlay as its mode argument.
Use cam overlay to select the same mode.
To select a different mode, use cam MODE.
Replace MODE with a mode that webcam-launch accepts.'

# launch Yazi in the notes directory
notes() {
    local notes_dir="$HOME/Documents/notes"
    [[ -d "$notes_dir" ]] || mkdir -p "$notes_dir"
    yazi "$notes_dir"
}

_ad_register notes projects notes 'Open Linux notes in Yazi; Create ~/Documents/notes if necessary and open it without changing the shell directory.' run '' \
    'When: You need to read or edit files in your Linux notes directory.
Example:
  notes
Result: The function makes ~/Documents/notes if it does not exist.
It opens that directory in Yazi.
Select the necessary file in Yazi.
The shell keeps its original directory when you close Yazi.
Use notes without arguments.'

work () {
  local base="$HOME/Projects/work"
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
          --prompt='work> ' \
          --preview 'ls -la --color=always "$HOME/Projects/work/{}" | sed -n "1,120p"'
  )" || return 0

  cd "$base/$choice" || return 1
}

_ad_register work projects work 'Choose a work project; Select a directory directly below ~/Projects/work and change to it.' run '' \
    'When: You need to change to a project in ~/Projects/work.
The directory ~/Projects/work/example must exist for this example.
Example:
  work
Result: The fzf picker lists directories directly in ~/Projects/work.
The list excludes hidden directories.
Type part of a directory name to reduce the list.
Select example with the arrow keys.
Press Enter to change to ~/Projects/work/example.
The function uses ~/Projects/work as a fixed path.'

# open a directory in Nautilus, detached from the terminal
open() {
  local target="${1:-.}"
  [[ -e "$target" ]] || {
    echo "❌ Missing: $target"
    return 1
  }
  nautilus "$target" &>/dev/null &!
}

_ad_register open apps 'open [PATH]' 'Open a path in Nautilus; Start the file manager detached and silent, at PATH or the current directory.' run '' \
    'When: You need to browse a directory in the graphical file manager.
Example:
  open .
Result: Nautilus opens the current directory in a new window.
The terminal stays free and shows no Nautilus log messages.
Use open PATH to open a different directory.
Use open without arguments to open the current directory.'
