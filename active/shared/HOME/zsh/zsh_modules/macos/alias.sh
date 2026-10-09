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
    'When: You want to edit the legacy Ghostty config on macOS.
Example:
  edit-ghostty
Result: Vim opens the config at
~/Library/Application Support/com.mitchellh.ghostty/config.
For the appdots config, use nvim ~/.config/ghostty/config.'

alias la="eza -lahG --icons --grid --group-directories-first"
alias ls="eza -lah --icons --group-directories-first"
alias tree="eza --tree"
