#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
# appdots/packages/macos/core.sh
# Cross-platform apps installed via Homebrew.

BREW_FORMULAE=(
  # --- Shell / CLI (the zsh modules and bin/ scripts assume these exist) ---
  bash # 4+ for the vendored omarchy-theme-color used by bin/macos/theme.sh
  starship
  zsh-autosuggestions
  zsh-syntax-highlighting
  fzf   # theme pick, fe/fda/fcd, herdr-fzf
  jq    # herdr-workspace, herdr-fzf (Omarchy's base manifest covers this on Linux)
  bat   # fzf previews
  tree  # fzf previews
  neovim
  yazi
  yq
  ripgrep

  # --- Eye candy / TUI toys ---
  cava
  cmatrix

  # Neovim uses native editing and syntax plugins; no LSP/formatter packages.
)

BREW_CASKS=(
  ghostty    # config in active/shared/.config/ghostty
  rectangle  # plist in active/macos/library/Preferences
  keepassxc
  nikitabobko/tap/aerospace # tiling WM, config in active/macos/.config/aerospace
  libreoffice
  font-fira-code-nerd-font
)

failures=()

case "${1:-}" in
  --check) check_only=true ;;
  '') check_only=false ;;
  *) printf 'Usage: %s [--check]\n' "$0" >&2; exit 2 ;;
esac
[[ $# -le 1 ]] || exit 2
if [[ "${DOTFILES_NONINTERACTIVE:-0}" == 1 || "$check_only" == true ]]; then
  repo_dir="${APP_DOTS_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)}"
  source "$repo_dir/lib/log.sh"
  command -v brew >/dev/null || { log_err 'Install Homebrew before unattended installation.'; exit 4; }
  # Cask installers can need privileges; test from the detached installer context.
  sudo -n true </dev/null || { log_err 'Unattended Homebrew casks require non-interactive sudo authorization.'; exit 4; }
  export NONINTERACTIVE=1 HOMEBREW_NO_AUTO_UPDATE=1
fi
[[ "$check_only" != true ]] || exit 0

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
    if ! brew install "$pkg"; then
      echo "  ✗ Failed: $pkg"
      failures+=("$pkg")
    fi
  fi
done

echo
echo "==> Installing Brew casks"
for pkg in "${BREW_CASKS[@]}"; do
  if is_cask_installed "$pkg"; then
    echo "  ✓ Already installed: $pkg"
  else
    echo "  + Installing (cask): $pkg"
    if ! brew install --cask "$pkg"; then
      echo "  ✗ Failed: $pkg"
      failures+=("$pkg")
    fi
  fi
done

echo
if (( ${#failures[@]} )); then
  printf 'Package installation failed: %s\n' "${failures[*]}" >&2
  exit 1
fi
echo "🎉 macOS packages done."
