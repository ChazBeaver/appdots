# launch Yazi in the notes directory
notes() {
    local notes_dir="$HOME/Projects/work/notes"
    [[ -d "$notes_dir" ]] || mkdir -p "$notes_dir"
    yazi "$notes_dir"
}

_ad_register notes projects notes 'Open macOS work notes in Yazi; Create ~/Projects/work/notes if necessary and open it without changing the shell directory.' run '' \
    'When: You need to read or edit files in your macOS work notes directory.
Example:
  notes
Result: The function makes ~/Projects/work/notes if it does not exist.
It opens that directory in Yazi.
Select the necessary file in Yazi.
The shell keeps its original directory when you close Yazi.
Use notes without arguments.'
