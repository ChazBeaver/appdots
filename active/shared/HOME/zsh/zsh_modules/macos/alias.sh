# For Mac
alias here='open .'

# Theme picker: fzf over the appdots themes, applies to Ghostty and Neovim,
# then reloads Ghostty (see README "Themes on macOS").
alias tt='theme pick'

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

alias la="eza -lahG --icons --grid --group-directories-first"
alias ls="eza -lah --icons --group-directories-first"
alias tree="eza --tree"
