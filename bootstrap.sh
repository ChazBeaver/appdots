#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
# appdots/bootstrap.sh
# One-time cold-boot orchestrator for a fresh machine.
# Runs: backup → packages → system tweaks → sync
#
# Run this ONCE on a new machine.
# For ongoing updates (after git pull) run ./sync.sh instead.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-${(%):-%N}}")" &>/dev/null && pwd)"

# shellcheck source=lib/log.sh
source "$SCRIPT_DIR/lib/log.sh"
# shellcheck source=lib/detect.sh
source "$SCRIPT_DIR/lib/detect.sh"
# shellcheck source=lib/env.sh
source "$SCRIPT_DIR/lib/env.sh"

OS="$(detect_os)"
ensure_appdots_env "$SCRIPT_DIR"

# Execute a stable copy so a git pull or edit cannot change a script while
# Bash is still reading it.
run_snapshot() {
  local script="$1"
  local snapshot status=0

  snapshot="$(mktemp)"
  cp -- "$script" "$snapshot"
  chmod 700 "$snapshot"
  bash "$snapshot" || status=$?
  rm -f -- "$snapshot"
  return "$status"
}

cat <<'EOF'

 _                 _       _
| |__   ___   ___ | |_ __| |_ _ __
| '_ \ / _ \ / _ \| __/ __| __| '_ \
| |_) | (_) | (_) | |_\__ \ |_| |_) |
|_.__/ \___/ \___/ \__|___/\__| .__/
                              |_|
          Cold-boot bootstrap

EOF

log_info "OS: $OS"
log_info "APP_DOTS_DIR: $APP_DOTS_DIR"
echo

# ---- 1. Backup ----
log_step "Step 1/4: Backup existing dotfiles"
"$SCRIPT_DIR/backup.sh"
echo

# ---- 2. Packages ----
pkg_script="$SCRIPT_DIR/packages/$OS/core.sh"
if [ -f "$pkg_script" ]; then
  log_step "Step 2/4: Install packages ($OS)"
  run_snapshot "$pkg_script"
else
  log_warn "Step 2/4: No package script for $OS — skipping"
fi
echo

# ---- 3. System tweaks ----
sys_dir="$SCRIPT_DIR/system/$OS"
if [ -d "$sys_dir" ]; then
  log_step "Step 3/4: Apply system tweaks ($OS)"
  find "$sys_dir" -mindepth 1 -maxdepth 1 -type f -name '*.sh' | sort | while read -r script; do
    echo "  ▶ $(basename "$script")"
    run_snapshot "$script"
  done
else
  log_warn "Step 3/4: No system/ dir for $OS — skipping"
fi
echo

# ---- 4. Sync ----
log_step "Step 4/4: Symlink sync"
"$SCRIPT_DIR/sync.sh"
echo

if [ "$OS" = "macos" ]; then
  log_info "macOS post-install notice:"
  echo "  If apps (e.g., Rectangle) don't pick up plist changes:"
  echo "  → restart the app, or run: killall cfprefsd"
  echo
fi

log_ok "Bootstrap complete."
log_info "From now on, just run ./sync.sh after git pull."
