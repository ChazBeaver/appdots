# ------------------------------------------------------------
# Linux Zsh Plugins (pacman installed)
# Loads only if packages exist
# ------------------------------------------------------------

# Guard: only run in interactive shells
[[ -o interactive ]] || return

# -----------------------------
# zsh-autosuggestions
# -----------------------------
ZSH_AUTOSUGGESTIONS_FILE="/usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"

if [[ -r "$ZSH_AUTOSUGGESTIONS_FILE" ]]; then
  source "$ZSH_AUTOSUGGESTIONS_FILE"

  # nicer defaults
  ZSH_AUTOSUGGEST_STRATEGY=(history completion)
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#666666'
fi


# # -----------------------------
# # zsh-autocomplete
# # -----------------------------
# ZSH_AUTOCOMPLETE_FILE="/usr/share/zsh/plugins/zsh-autocomplete/zsh-autocomplete.plugin.zsh"
#
# if [[ -r "$ZSH_AUTOCOMPLETE_FILE" ]]; then
#   source "$ZSH_AUTOCOMPLETE_FILE"
# fi
