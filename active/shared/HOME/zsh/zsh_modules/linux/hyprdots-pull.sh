#!/usr/bin/env bash

# Only apply strict mode when running as a standalone script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail
  IFS=$'\n\t'
fi

# ============================================================================
# Update Dotfiles Repos
# Pulls the latest changes using `git pull --rebase`
# ============================================================================

DOTFILES_DIRS=(
  # "$HOME/Projects/appdots"
  "$HOME/Projects/home/hyprdots"
)

for dir in "${DOTFILES_DIRS[@]}"; do
  if [ -d "$dir/.git" ]; then
    echo "🔄 Updating: $dir"
    git -C "$dir" pull --rebase || echo "⚠️  Failed to update $dir"
  else
    echo "⚠️  Skipping: $dir (not a git repo)"
  fi
done

echo "✅ All dotfiles repos updated."
