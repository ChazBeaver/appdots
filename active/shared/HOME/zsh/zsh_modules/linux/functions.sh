# Run Cava based on proper config file location with Omarchy
cava() {
  local config="$HOME/.config/omarchy/current/theme/cava_theme"
  command cava -p "$config" "$@"
}

_ad_register cava apps 'cava [ARGUMENTS]' 'Launch Cava with the active Omarchy theme configuration.' run '' \
    'When: You want to see audio levels with your active Omarchy theme.
Example:
  cava
Result: Cava starts with the theme file at
~/.config/omarchy/current/theme/cava_theme.'

cam() {
  webcam-launch "${1:-overlay}"
}

_ad_register cam apps 'cam [MODE]' 'Launch the webcam, using overlay mode by default.' run '' \
    'When: You want to open your camera in overlay mode.
Example:
  cam overlay
Result: The function starts webcam-launch in overlay mode.
If you use cam without an argument, overlay is the default mode.'

# launch Yazi in the notes directory
notes() {
    local notes_dir="$HOME/Documents/notes"
    [[ -d "$notes_dir" ]] || mkdir -p "$notes_dir"
    yazi "$notes_dir"
}

_ad_register notes projects notes 'Create the Linux notes directory if needed and open it in Yazi.' run '' \
    'When: You want to open your Linux notes in Yazi.
Example:
  notes
Result: The function makes ~/Documents/notes if it does not exist.
It then opens that directory in Yazi.'

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
    'When: You want to open a project in ~/Projects/work.
Example:
  work
Result: The picker lists directories directly under ~/Projects/work.
Select example to change into ~/Projects/work/example.'
