# For Mac
alias here='open .'

# Theme picker: fzf over the appdots themes, applies to Ghostty and Neovim,
# then reloads Ghostty (see README "Themes on macOS").
alias tt='theme pick'

# Edit Ghostty Config
edit-ghostty() {
    vim $HOME/Library/Application\ Support/com.mitchellh.ghostty/config
}

_ad_register edit-ghostty utilities edit-ghostty 'Open the macOS Ghostty configuration in Vim.' run '' \
    'When: You need to edit the older Ghostty configuration path on macOS.
Example:
  edit-ghostty
Result: The function opens this configuration file in Vim:
  ~/Library/Application Support/com.mitchellh.ghostty/config
Make the necessary changes in Vim.
Save the file with :w.
Close Vim with :q.

Appdots uses ~/.config/ghostty/config for its managed configuration.
To edit that file, use this command:
  nvim ~/.config/ghostty/config'

alias la="eza -lahG --icons --grid --group-directories-first"
alias ls="eza -lah --icons --group-directories-first"
alias tree="eza --tree"
