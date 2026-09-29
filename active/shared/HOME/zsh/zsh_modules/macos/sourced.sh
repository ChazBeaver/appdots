# Homebrew zsh plugins. Each is skipped quietly when not installed.
_zsh_hl="${HOMEBREW_PREFIX:-/opt/homebrew}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
[ -r "$_zsh_hl" ] && source "$_zsh_hl"
unset _zsh_hl
#source $HOMEBREW_PREFIX/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh
