#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$REPO_DIR/lib/log.sh"
command -v python3 >/dev/null || { log_err 'Install Python 3 before using the unattended installer.'; exit 4; }
exec python3 -B "$REPO_DIR/scripts/unattended-install.py" "$@"
