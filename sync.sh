#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
# appdots/sync.sh
# Declarative symlink sync. Idempotent, safe to run repeatedly.
# Does NOT run imperative OS mutations — see bootstrap.sh for that.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-${(%):-%N}}")" &>/dev/null && pwd)"
ACTIVE_DIR="$SCRIPT_DIR/active"
BIN_DIR="$SCRIPT_DIR/bin"

# shellcheck source=lib/log.sh
source "$SCRIPT_DIR/lib/log.sh"
# shellcheck source=lib/detect.sh
source "$SCRIPT_DIR/lib/detect.sh"
# shellcheck source=lib/link.sh
source "$SCRIPT_DIR/lib/link.sh"
# shellcheck source=lib/env.sh
source "$SCRIPT_DIR/lib/env.sh"

OS="$(detect_os)"

cat <<'EOF'

  ___  __________________ _____ _____ _____
 / _ \ | ___ \ ___ \  _  \  _  |_   _/  ___|
/ /_\ \| |_/ / |_/ / | | | | | | | | \ `--.
|  _  ||  __/|  __/| | | | | | | | |  `--. \
| | | || |   | |   | |/ /\ \_/ / | | /\__/ /
\_| |_/\_|   \_|   |___/  \___/  \_/ \____/

                Syncing Appdots

EOF

# ---- Persist APP_DOTS_DIR + alias ----
ensure_appdots_env "$SCRIPT_DIR"
log_info "APP_DOTS_DIR: $APP_DOTS_DIR"

# ---- Symlink sync ----
log_step "Linking shared dotfiles..."
install_scope "$ACTIVE_DIR/shared"

log_step "Linking $OS-specific dotfiles..."
install_scope "$ACTIVE_DIR/$OS"

# ---- Bin sync ----
install_bin_scope "$BIN_DIR" "$OS"

echo
log_ok "Sync complete."
log_info "Open a new terminal session to use the synced shell config."
