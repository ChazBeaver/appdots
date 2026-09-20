#!/usr/bin/env bash

# ============================================================================
# Load persistent dotfiles environment variables (like APP_DOTS_DIR, HYPR_DOTS_DIR)
# ============================================================================

DOTFILES_ENV="$HOME/.dotfiles-env.sh"

if [ -f "$DOTFILES_ENV" ]; then
  source "$DOTFILES_ENV"
  # Optional: uncomment the next line if you want a visual confirmation
  # echo "✅ Loaded environment variables from $DOTFILES_ENV"
fi

export EDITOR=nvim
export VISUAL=nvim
export TERM=xterm-256color
