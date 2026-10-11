# Run Cava based on proper config file location with Omarchy
cava() {
  local config="$HOME/.config/omarchy/current/theme/cava_theme"
  command cava -p "$config" "$@"
}

_ad_register cava apps 'cava [ARGUMENTS]' 'Show audio levels with Cava; Start Cava with the Omarchy theme configuration and any supplied arguments.' run '' \
    'When: You need to see audio levels with the current Omarchy theme.
The Cava program and the theme configuration file must exist.
Example:
  cava
Result: The function starts Cava with this theme configuration file:
  ~/.config/omarchy/current/theme/cava_theme
Cava shows the audio levels with the colors from that file.
The function passes any arguments after cava to the Cava program.'

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
