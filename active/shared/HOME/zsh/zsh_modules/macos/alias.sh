# For Mac
alias here='open .'

# Theme picker: fzf over the appdots themes, applies to Ghostty and Neovim,
# then reloads Ghostty (see README "Themes on macOS").
alias tt='theme pick'

# Edit Ghostty Config
edit-ghostty() {
    vim $HOME/Library/Application\ Support/com.mitchellh.ghostty/config
}

_ad_register edit-ghostty utilities 'edit-ghostty' 'Open the macOS Ghostty configuration in Vim.' run

alias la="eza -lahG --icons --grid --group-directories-first"
alias ls="eza -lah --icons --group-directories-first"
alias tree="eza --tree"
