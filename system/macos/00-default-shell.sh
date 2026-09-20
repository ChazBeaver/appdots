#!/usr/bin/env bash
set -euo pipefail
# appdots/system/macos/00-default-shell.sh
# Set zsh as the default login shell.

account_user="${USER:-$(id -un)}"
current_shell="$(dscl . -read "/Users/$account_user" UserShell | awk '{print $2}')"

if [[ "$current_shell" == */zsh ]]; then
  echo "✓ zsh is already the default shell"
  exit 0
fi

if ! command -v zsh >/dev/null 2>&1; then
  echo "✗ zsh is not installed" >&2
  exit 1
fi

zsh_path="$(command -v zsh)"

if ! grep -qx "$zsh_path" /etc/shells; then
  echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
fi

echo "==> Changing default shell to $zsh_path"
chsh -s "$zsh_path"

current_shell="$(dscl . -read "/Users/$account_user" UserShell | awk '{print $2}')"
if [[ "$current_shell" != "$zsh_path" ]]; then
  echo "✗ Login shell is still $current_shell; expected $zsh_path" >&2
  exit 1
fi

echo "✓ Log out and back in for the change to take effect."
