#!/usr/bin/env bash
set -euo pipefail
# Verify that the account login shell matches the installed zsh.
# Read-only: bootstrap.sh owns changing the account shell.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-${(%):-%N}}")" &>/dev/null && pwd)"
APPDOTS_DIR="$(cd -- "$SCRIPT_DIR/.." &>/dev/null && pwd)"

# shellcheck source=../lib/log.sh
source "$APPDOTS_DIR/lib/log.sh"
# shellcheck source=../lib/detect.sh
source "$APPDOTS_DIR/lib/detect.sh"

OS="$(detect_os)"
account_user="${USER:-$(id -un)}"

echo
log_info "Default login shell check ($OS)"
echo

if ! zsh_path="$(command -v zsh 2>/dev/null)" || [ -z "$zsh_path" ]; then
  log_err "zsh is not installed. Run ./bootstrap.sh to install and configure it."
  exit 1
fi

case "$OS" in
  linux)
    current_shell="$(getent passwd "$account_user" | cut -d: -f7)"
    ;;
  macos)
    current_shell="$(dscl . -read "/Users/$account_user" UserShell | awk '{print $2}')"
    ;;
  *)
    log_err "Unsupported OS: $OS"
    exit 1
    ;;
esac

if [ "$current_shell" != "$zsh_path" ]; then
  log_err "Login shell is $current_shell; expected $zsh_path. Run ./bootstrap.sh to configure it."
  exit 1
fi

log_ok "Login shell is $zsh_path."
