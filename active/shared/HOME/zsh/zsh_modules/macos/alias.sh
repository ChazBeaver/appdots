# For Mac
alias here='open .'

# Edit Ghostty Config
edit-ghostty() {
    vim $HOME/Library/Application\ Support/com.mitchellh.ghostty/config
}

_ad_register edit-ghostty utilities 'edit-ghostty' 'Open the macOS Ghostty configuration in Vim.' run

alias la="eza -lahG --icons --grid --group-directories-first"
alias ls="eza -lah --icons --group-directories-first"
alias tree="eza --tree"
