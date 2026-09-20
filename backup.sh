#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
# appdots/backup.sh
# Back up any real (non-symlink) files that sync.sh would replace.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-${(%):-%N}}")" &>/dev/null && pwd)"
ACTIVE_DIR="$SCRIPT_DIR/active"

# shellcheck source=lib/log.sh
source "$SCRIPT_DIR/lib/log.sh"
# shellcheck source=lib/detect.sh
source "$SCRIPT_DIR/lib/detect.sh"
# shellcheck source=lib/backup.sh
source "$SCRIPT_DIR/lib/backup.sh"

OS="$(detect_os)"

cat <<'EOF'
                       _       _
  __ _ _ __  _ __   __| | ___ | |_ ___
 / _` | '_ \| '_ \ / _` |/ _ \| __/ __|
| (_| | |_) | |_) | (_| | (_) | |_\__ \
 \__,_| .__/| .__/ \__,_|\___/ \__|___/
      |_|   |_|
 _                _                     _
| |__   __ _  ___| | ___   _ _ __   ___| |__
| '_ \ / _` |/ __| |/ / | | | '_ \ / __| '_ \
| |_) | (_| | (__|   <| |_| | |_) |\__ \ | | |
|_.__/ \__,_|\___|_|\_\\__,_| .__(_)___/_| |_|
                            |_|
EOF

echo
log_info "Backing up dotfiles before sync..."
echo

backup_layer "$ACTIVE_DIR/shared"
backup_layer "$ACTIVE_DIR/$OS"

echo
log_ok "Backup complete. You're ready to run ./sync.sh"
