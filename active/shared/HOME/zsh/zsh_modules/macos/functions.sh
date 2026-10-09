# launch Yazi in the notes directory
notes() {
    local notes_dir="$HOME/Projects/work/notes"
    [[ -d "$notes_dir" ]] || mkdir -p "$notes_dir"
    yazi "$notes_dir"
}

_ad_register notes projects notes 'Create the macOS work notes directory if needed and open it in Yazi.' run '' \
    'When: You want to open your macOS work notes in Yazi.
Example:
  notes
Result: The function makes ~/Projects/work/notes if it does not exist.
It then opens that directory in Yazi.'
