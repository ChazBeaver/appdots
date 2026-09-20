#!/usr/bin/env bash
set -euo pipefail

echo "Applying Dock settings..."

# Behavior
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock magnification -bool false
defaults write com.apple.dock tilesize -int 128
defaults write com.apple.dock largesize -int 16

# Keep recent apps visible for now, since your dump showed recent-apps populated.
# If you later want them hidden, flip this to false.
defaults write com.apple.dock show-recents -bool true

if command -v dockutil >/dev/null 2>&1; then
  echo "Rebuilding Dock with dockutil..."

  dockutil --no-restart --remove all || true

  dockutil --no-restart --add "/System/Applications/Apps.app"
  dockutil --no-restart --add "/System/Applications/Calendar.app"
  dockutil --no-restart --add "/System/Applications/System Settings.app"

  # Downloads stack/folder
  dockutil --no-restart --add "$HOME/Downloads" \
    --view auto \
    --display folder \
    --sort name \
    --section others

  killall Dock || true
else
  echo "dockutil not found."
  echo "Install it with: brew install dockutil"
  echo "Dock behavior settings were applied, but Dock item layout was not rebuilt."
  killall Dock || true
fi
