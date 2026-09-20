#!/usr/bin/env bash
set -euo pipefail
# appdots/packages/linux/core.sh
# Cross-platform apps + their Linux install mechanics.
# Environment-specific packages (ddcutil, wev, GTK themes, etc.) live in hyprdots.

PACMAN_PKGS=(
  # --- Shell / CLI ---
  starship
  zsh
  zsh-autosuggestions
  zsh-autocomplete
  keepassxc
  yazi
  yq
  python-virtualenv
  tuicr

  # --- Fonts ---
  ttf-firacode-nerd
  ttf-cascadia-mono-nerd
  noto-fonts-extra

  # --- Productivity ---
  libreoffice-fresh

  # --- Eye candy / TUI toys ---
  cava
  cmatrix

  # --- Terminals ---
  kitty
  ghostty
  herdr
)

AUR_PKGS=(
  cbonsai-git
  discordo-git
  opencode
)

failures=()

is_installed() {
  pacman -Q "$1" >/dev/null 2>&1
}

install_yay() {
  if command -v yay >/dev/null 2>&1; then
    return
  fi
  echo "==> Installing yay (AUR helper)"
  sudo pacman -S --needed --noconfirm git base-devel
  local tmp_dir
  tmp_dir=$(mktemp -d)
  git clone https://aur.archlinux.org/yay.git "$tmp_dir/yay"
  pushd "$tmp_dir/yay" >/dev/null
  makepkg -si --noconfirm
  popd >/dev/null
  rm -rf "$tmp_dir"
}

echo "==> Refreshing package databases"
sudo pacman -Sy --noconfirm

echo "==> Installing PACMAN packages"
for pkg in "${PACMAN_PKGS[@]}"; do
  if is_installed "$pkg"; then
    echo "  ✓ Already installed: $pkg"
  else
    echo "  + Installing: $pkg"
    if ! sudo pacman -S --needed --noconfirm "$pkg"; then
      echo "  ✗ Failed: $pkg"
      failures+=("$pkg")
    fi
  fi
done

echo
echo "==> Ensuring AUR helper (yay)"
install_yay

echo
echo "==> Installing AUR packages"
for pkg in "${AUR_PKGS[@]}"; do
  if is_installed "$pkg"; then
    echo "  ✓ Already installed: $pkg"
  else
    echo "  + Installing (AUR): $pkg"
    if ! yay -S --needed --noconfirm "$pkg"; then
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
echo "🎉 Linux packages done."
