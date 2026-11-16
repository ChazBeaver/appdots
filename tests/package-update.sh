#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
fixture="$(mktemp -d)"
trap 'rm -rf -- "$fixture"' EXIT
mkdir -p "$fixture/bin"
cat > "$fixture/bin/omarchy" <<'EOF'
#!/usr/bin/env bash
printf 'omarchy %s\n' "$*" >> "$UPDATE_TEST_LOG"
exit 42
EOF
cat > "$fixture/bin/sudo" <<'EOF'
#!/usr/bin/env bash
printf 'sudo %s\n' "$*" >> "$UPDATE_TEST_LOG"
exit 42
EOF
chmod +x "$fixture/bin/omarchy" "$fixture/bin/sudo"
if UPDATE_TEST_LOG="$fixture/log" PATH="$fixture/bin:$PATH" bash "$repo/packages/linux/core.sh" > "$fixture/output" 2>&1; then
  echo 'FAIL: failed update allowed package installation' >&2
  exit 1
fi
if [[ -d /usr/share/omarchy ]]; then
  grep -Fxq 'omarchy update -y' "$fixture/log"
else
  grep -Fxq 'sudo pacman -Syu --noconfirm' "$fixture/log"
fi
[[ "$(wc -l < "$fixture/log")" -eq 1 ]] || { echo 'FAIL: commands ran after the failed update' >&2; exit 1; }
echo 'PASS: package installation stops after a failed full system update'

cat > "$fixture/bin/brew" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  update) exit 0 ;;
  list|install) exit 1 ;;
  *) exit 2 ;;
esac
EOF
chmod +x "$fixture/bin/brew"
if PATH="$fixture/bin:$PATH" bash "$repo/packages/macos/core.sh" > "$fixture/macos-output" 2>&1; then
  echo 'FAIL: failed Homebrew installations reported success' >&2
  exit 1
fi
grep -Fq 'Package installation failed:' "$fixture/macos-output"
echo 'PASS: Homebrew package failures propagate'
