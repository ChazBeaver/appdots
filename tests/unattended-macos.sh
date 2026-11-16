#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
fixture="$(mktemp -d)"
trap 'rm -rf -- "$fixture"' EXIT
mkdir "$fixture/bin"
export MAC_INSTALL_TRACE="$fixture/trace" DOTFILES_NONINTERACTIVE=1
cat > "$fixture/bin/sudo" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == -n ]] || exit 99
exit "${DENY_SUDO:-0}"
EOF
cat > "$fixture/bin/brew" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MAC_INSTALL_TRACE"
[[ "$NONINTERACTIVE" == 1 && "$HOMEBREW_NO_AUTO_UPDATE" == 1 ]] || exit 99
case "$1" in
  update) exit "${UPDATE_EXIT:-0}" ;;
  list) exit 1 ;;
  install) exit "${PACKAGE_EXIT:-0}" ;;
  *) exit 99 ;;
esac
EOF
chmod +x "$fixture"/bin/*
export PATH="$fixture/bin:$PATH"
run_package() {
  local expected="$1" status=0; shift
  : > "$MAC_INSTALL_TRACE"
  bash "$repo/packages/macos/core.sh" "$@" > "$fixture/output" 2>&1 || status=$?
  [[ "$status" == "$expected" ]] || { cat "$fixture/output" >&2; printf 'FAIL: status %s, expected %s\n' "$status" "$expected" >&2; exit 1; }
}
run_package 0 --check
[[ ! -s "$MAC_INSTALL_TRACE" ]]
DENY_SUDO=1 run_package 4
[[ ! -s "$MAC_INSTALL_TRACE" ]]
run_package 0
grep -q '^install --cask ' "$MAC_INSTALL_TRACE"
PACKAGE_EXIT=42 run_package 1
UPDATE_EXIT=42 run_package 42
[[ "$(cat "$MAC_INSTALL_TRACE")" == update ]]
printf '%s\n' 'PASS: unattended Homebrew preflight, formulae/casks, and update/install failures'
