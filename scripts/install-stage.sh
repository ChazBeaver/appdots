#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$REPO_DIR/lib/log.sh"
source "$REPO_DIR/lib/detect.sh"
export APP_DOTS_DIR="$REPO_DIR" DOTFILES_NONINTERACTIVE=1
os="$(detect_os)"
case "${1:-}" in
  preflight)
    [[ "$(id -u)" != 0 ]] || { log_err 'Run as the target user, not root.'; exit 4; }
    [[ "$os" == linux || "$os" == macos ]] || { log_err 'Supported platforms: Arch/Omarchy Linux and macOS.'; exit 4; }
    [[ -w "$HOME" ]] || { log_err 'The user home directory is not writable.'; exit 4; }
    for command_name in git sudo python3; do
      command -v "$command_name" >/dev/null || { log_err "Missing prerequisite: $command_name"; exit 4; }
    done
    bash "$REPO_DIR/packages/$os/core.sh" --check
    account_user="$(id -un)"
    if [[ "$os" == linux ]]; then
      current_shell="$(getent passwd "$account_user" | cut -d: -f7)"
      [[ -n "$current_shell" ]] || { log_err 'Cannot determine the account shell.'; exit 4; }
      zsh_path="$(command -v zsh || printf /usr/bin/zsh)"
      if [[ "$current_shell" != "$zsh_path" ]]; then
        sudo -n -l -- "$(command -v chsh)" -s "$zsh_path" "$account_user" >/dev/null || { log_err 'Authorize the login-shell change before installation.'; exit 4; }
      fi
      if ! grep -Fxq "$zsh_path" /etc/shells; then
        sudo -n -l -- "$(command -v tee)" -a /etc/shells >/dev/null || { log_err 'Authorize registration of zsh in /etc/shells before installation.'; exit 4; }
      fi
    else
      current_shell="$(dscl . -read "/Users/$account_user" UserShell | awk '{print $2}')"
      [[ "$current_shell" == */zsh ]] || { log_err 'Set zsh as the login shell before unattended macOS installation.'; exit 4; }
    fi
    log_ok 'Unattended installation prerequisites are ready.'
    ;;
  install) exec "$REPO_DIR/bootstrap.sh" ;;
  verify) exec "$REPO_DIR/doctor.sh" ;;
  *) log_err 'Expected preflight, install, or verify.'; exit 2 ;;
esac
