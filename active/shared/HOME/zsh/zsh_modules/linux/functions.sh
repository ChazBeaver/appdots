# Run Cava based on proper config file location with Omarchy
cava() {
  local config="$HOME/.config/omarchy/current/theme/cava_theme"
  command cava -p "$config" "$@"
}

_ad_register cava apps 'cava [ARGUMENTS]' 'Launch Cava with the active Omarchy theme configuration.' run '' \
    'When: You need to see audio levels with the current Omarchy theme.
Example:
  cava
Result: The function starts Cava with this theme configuration file:
  ~/.config/omarchy/current/theme/cava_theme
Cava shows the audio levels with the colors from that file.
The function passes any arguments after cava to the Cava program.'

cam() {
  webcam-launch "${1:-overlay}"
}

_ad_register cam apps 'cam [MODE]' 'Launch the webcam, using overlay mode by default.' run '' \
    'When: You need to open the webcam in overlay mode.
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

_ad_register notes projects notes 'Create the Linux notes directory if needed and open it in Yazi.' run '' \
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

_ad_register work projects work 'Choose a repository under ~/Projects/work and change into it.' run '' \
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
