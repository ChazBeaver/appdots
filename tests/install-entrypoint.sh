#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
fixture="$(mktemp -d)"
trap 'rm -rf -- "$fixture"' EXIT
mkdir -p "$fixture/repo/scripts" "$fixture/repo/lib" "$fixture/repo/packages/macos" "$fixture/repo/packages/linux" "$fixture/bin"
cp "$repo/install.sh" "$fixture/repo/"
cp "$repo/scripts/"* "$fixture/repo/scripts/"
cp "$repo/lib/log.sh" "$repo/lib/detect.sh" "$fixture/repo/lib/"
export ENTRY_TRACE="$fixture/trace" XDG_STATE_HOME="$fixture/state"
cat > "$fixture/repo/packages/macos/core.sh" <<'EOF'
#!/usr/bin/env bash
printf 'packages %s\n' "$*" >> "$ENTRY_TRACE"
[[ "$DOTFILES_NONINTERACTIVE" == 1 && "$1" == --check ]] || exit 99
exit "${CHECK_EXIT:-0}"
EOF
cp "$fixture/repo/packages/macos/core.sh" "$fixture/repo/packages/linux/"
cat > "$fixture/repo/bootstrap.sh" <<'EOF'
#!/usr/bin/env bash
printf 'bootstrap\n' >> "$ENTRY_TRACE"
[[ "$DOTFILES_NONINTERACTIVE" == 1 ]] || exit 99
exit "${BOOTSTRAP_EXIT:-0}"
EOF
cat > "$fixture/repo/doctor.sh" <<'EOF'
#!/usr/bin/env bash
printf 'doctor\n' >> "$ENTRY_TRACE"
exit "${DOCTOR_EXIT:-0}"
EOF
cat > "$fixture/bin/uname" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${FIXTURE_OS:-Darwin}"
EOF
cat > "$fixture/bin/id" <<'EOF'
#!/usr/bin/env bash
[[ "$1" != -u ]] || { printf '1000\n'; exit; }
printf 'fixture-user\n'
EOF
cat > "$fixture/bin/getent" <<'EOF'
#!/usr/bin/env bash
printf 'fixture-user:x:1000:1000::/unused:%s\n' "$(command -v zsh || printf /usr/bin/zsh)"
EOF
printf '%s\n' '#!/usr/bin/env bash' 'printf "UserShell: /bin/zsh\n"' > "$fixture/bin/dscl"
printf '%s\n' '#!/usr/bin/env bash' '[[ "$1" == -n && "$2" == -l ]]' > "$fixture/bin/sudo"
chmod +x "$fixture/repo/"*.sh "$fixture/bin/"*
export PATH="$fixture/bin:$PATH"
run_install() {
  local expected="$1" status=0
  : > "$ENTRY_TRACE"
  "$fixture/repo/install.sh" --non-interactive > "$fixture/output" 2>&1 || status=$?
  [[ "$status" == "$expected" ]] || { cat "$fixture/output"; exit 1; }
}
run_install 0
[[ "$(cat "$ENTRY_TRACE")" == $'packages --check\nbootstrap\ndoctor' ]]
FIXTURE_OS=Linux run_install 0
[[ "$(cat "$ENTRY_TRACE")" == $'packages --check\nbootstrap\ndoctor' ]]
CHECK_EXIT=4 run_install 4
[[ "$(cat "$ENTRY_TRACE")" == 'packages --check' ]]
BOOTSTRAP_EXIT=42 run_install 42
! grep -q '^doctor' "$ENTRY_TRACE"
DOCTOR_EXIT=43 run_install 43
grep -q '^doctor' "$ENTRY_TRACE"
FIXTURE_OS=FreeBSD run_install 4
[[ ! -s "$ENTRY_TRACE" ]]
printf '%s\n' 'PASS: owner entrypoint platform dispatch, bootstrap reuse, and doctor failures'
