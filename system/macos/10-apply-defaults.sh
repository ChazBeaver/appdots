#!/usr/bin/env bash
set -euo pipefail

echo "Applying macOS defaults..."

defaults write -g com.apple.swipescrolldirection -bool false
defaults write -g com.apple.mouse.scaling -float -1
defaults write -g com.apple.trackpad.scaling -float 3
defaults write -g InitialKeyRepeat -int 15
defaults write -g KeyRepeat -int 1
