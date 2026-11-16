#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
python3 -B "$REPO_DIR/tests/unattended.py"
