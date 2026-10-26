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

# Edit Ghostty Config
edit-ghostty() {
    vim $HOME/Library/Application\ Support/com.mitchellh.ghostty/config
}

_ad_register edit-ghostty utilities edit-ghostty 'Edit the older Ghostty config; Open the macOS Application Support configuration with vim, which appdots maps to Neovim.' run '' \
    'When: You need to edit the older Ghostty configuration file on macOS.
Example:
  edit-ghostty
Result: The function opens this configuration file with vim:
  ~/Library/Application Support/com.mitchellh.ghostty/config
In the managed shell, the vim alias selects Neovim.
Make the necessary changes in the editor.
Save the file with :w.
Close the editor with :q.

Appdots uses ~/.config/ghostty/config for its managed configuration.
To edit that file, use this command:
  nvim ~/.config/ghostty/config'
