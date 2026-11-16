#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
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
  opencode

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
  ghostty
  herdr

  # Neovim uses native editing and syntax plugins; no LSP/formatter packages.
)

AUR_PKGS=(
  # No Appdots AUR packages; Hyprdots owns desktop plugin requirements.
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
  source "$repo_dir/lib/unattended.sh"
  command -v pacman >/dev/null || { log_err 'Arch Linux with pacman is required.'; exit 4; }
  unattended_linux_ready
  sudo -n -l -- "$(command -v pacman)" -S --needed --noconfirm -- "${PACMAN_PKGS[@]}" >/dev/null || {
    log_err 'Authorize unattended pacman installation before running this installer.'; exit 4;
  }
  if (( ${#AUR_PKGS[@]} )); then
    command -v yay >/dev/null || { log_err 'Install yay before unattended installation.'; exit 4; }
  fi
  [[ "$check_only" != true ]] || exit 0
  # Use the existing sync databases. Never refresh them without a full upgrade.
  sudo -n pacman -S --needed --noconfirm -- "${PACMAN_PKGS[@]}"
  if (( ${#AUR_PKGS[@]} )); then
    yay -S --needed --noconfirm --sudoflags=-n --nosudoloop -- "${AUR_PKGS[@]}"
  fi
  for pkg in "${PACMAN_PKGS[@]}" "${AUR_PKGS[@]}"; do pacman -Q "$pkg" >/dev/null; done
  exit 0
fi

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

echo "==> Updating the system before installing packages"
if [[ -d /usr/share/omarchy ]]; then
  if ! command -v omarchy >/dev/null 2>&1; then
    echo "Omarchy is present but its update command is unavailable" >&2
    exit 1
  fi
  omarchy update -y
  # Do not install further packages into a system awaiting a required reboot.
  kernel_seen=false
  current_kernel_found=false
  running_kernel="$(uname -r)"
  for kernel_image in /usr/lib/modules/*/vmlinuz; do
    [[ -f "$kernel_image" ]] || continue
    pacman -Qo "$kernel_image" >/dev/null 2>&1 || continue
    kernel_seen=true
    [[ "$(basename "$(dirname "$kernel_image")")" != "$running_kernel" ]] || current_kernel_found=true
  done
  if [[ -f "$HOME/.local/state/omarchy/reboot-required" ]] ||
     [[ "$kernel_seen" == true && "$current_kernel_found" == false ]]; then
    echo "A reboot is required before installing Appdots packages. Reboot and rerun bootstrap." >&2
    exit 1
  fi
else
  sudo pacman -Syu --noconfirm
fi

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

if (( ${#AUR_PKGS[@]} )); then
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
fi

echo
if (( ${#failures[@]} )); then
  printf 'Package installation failed: %s\n' "${failures[*]}" >&2
  exit 1
fi
echo "🎉 Linux packages done."
