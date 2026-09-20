#!/usr/bin/env bash
set -euo pipefail
# appdots/packages/macos/core.sh
# Cross-platform apps installed via Homebrew.

BREW_FORMULAE=(
  # --- Shell / CLI ---
  zsh-autosuggestions
  yazi
  yq
  ripgrep

  # --- Eye candy / TUI toys ---
  cava
  cmatrix

  # --- Fun ---
  cbonsai
)

BREW_CASKS=(
  keepassxc
  nikitabobko/tap/aerospace # tiling WM, config in active/macos/.config/aerospace
  kitty
  libreoffice
  font-fira-code-nerd-font
)

install_homebrew() {
  if command -v brew >/dev/null 2>&1; then
    return
  fi
  echo "==> Installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Add brew to PATH for this session (Apple Silicon vs Intel)
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

is_formula_installed() {
  brew list --formula "$1" >/dev/null 2>&1
}

is_cask_installed() {
  brew list --cask "$1" >/dev/null 2>&1
}

echo "==> Ensuring Homebrew"
install_homebrew

echo
echo "==> Updating Homebrew"
brew update

echo
echo "==> Installing Brew formulae"
for pkg in "${BREW_FORMULAE[@]}"; do
  if is_formula_installed "$pkg"; then
    echo "  ✓ Already installed: $pkg"
  else
    echo "  + Installing: $pkg"
    brew install "$pkg" || echo "  ✗ Failed: $pkg"
  fi
done

echo
echo "==> Installing Brew casks"
for pkg in "${BREW_CASKS[@]}"; do
  if is_cask_installed "$pkg"; then
    echo "  ✓ Already installed: $pkg"
  else
    echo "  + Installing (cask): $pkg"
    brew install --cask "$pkg" || echo "  ✗ Failed: $pkg"
  fi
done

echo
echo "🎉 macOS packages done."
