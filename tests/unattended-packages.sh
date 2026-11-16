#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
fixture="$(mktemp -d)"
trap 'rm -rf -- "$fixture"' EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
mkdir -p "$fixture/bin" "$fixture/repo/packages/linux" "$fixture/repo/lib" "$fixture/user" "$fixture/modules"
export INSTALL_TEST_LOG="$fixture/trace"
cat > "$fixture/bin/sudo" <<'STUB'
#!/usr/bin/env bash
printf 'sudo %s\n' "$*" >> "$INSTALL_TEST_LOG"
[[ "$1" == -n ]] || exit 99
[[ "$2" != -l ]] || exit "${DENY_SUDO:-0}"
exit "${PACKAGE_EXIT:-0}"
STUB
cat > "$fixture/bin/pacman" <<'STUB'
#!/usr/bin/env bash
case "$1" in
  -Qu) printf '%s' "${PENDING_UPDATES:-}"; exit "${QUERY_EXIT:-0}" ;;
  -Qo|-Q) exit 0 ;;
  *) exit 99 ;;
esac
STUB
cat > "$fixture/bin/uname" <<'STUB'
#!/usr/bin/env bash
[[ "$1" != -r ]] || { printf 'fixture-kernel\n'; exit; }
/usr/bin/uname "$@"
STUB
cat > "$fixture/bin/yay" <<'STUB'
#!/usr/bin/env bash
printf 'yay %s\n' "$*" >> "$INSTALL_TEST_LOG"
[[ " $* " == *' --sudoflags=-n '* && " $* " == *' --nosudoloop '* ]] || exit 99
exit "${PACKAGE_EXIT:-0}"
STUB
printf '%s\n' '#!/usr/bin/env bash' 'exit 1' > "$fixture/bin/pgrep"
printf '%s\n' '#!/usr/bin/env bash' 'exit 99' > "$fixture/bin/omarchy"
chmod +x "$fixture"/bin/*
export PATH="$fixture/bin:$PATH"
source "$repo/lib/log.sh"
source "$repo/lib/unattended.sh"
expect_ready() {
  local expected="$1" status=0
  unattended_linux_ready "$fixture/user" "$fixture/modules" > "$fixture/ready.out" 2>&1 || status=$?
  [[ "$status" == "$expected" ]] || fail "readiness returned $status, expected $expected"
}
expect_ready 0
QUERY_EXIT=1 expect_ready 0
PENDING_UPDATES='package 1 -> 2' expect_ready 4
QUERY_EXIT=2 expect_ready 4
mkdir -p "$fixture/user/.local/state/omarchy"
touch "$fixture/user/.local/state/omarchy/reboot-required"
expect_ready 3
rm "$fixture/user/.local/state/omarchy/reboot-required"
mkdir -p "$fixture/modules/new-kernel"
touch "$fixture/modules/new-kernel/vmlinuz"
expect_ready 3
mkdir -p "$fixture/modules/fixture-kernel"
touch "$fixture/modules/fixture-kernel/vmlinuz"
expect_ready 0

# Exercise the actual package entrypoint with readiness isolated above.
cp "$repo"/packages/linux/* "$fixture/repo/packages/linux/"
cp "$repo/lib/log.sh" "$fixture/repo/lib/"
printf '%s\n' 'unattended_linux_ready() { return "${READINESS_EXIT:-0}"; }' > "$fixture/repo/lib/unattended.sh"
export APP_DOTS_DIR="$fixture/repo" DOTFILES_NONINTERACTIVE=1
if [[ -f "$fixture/repo/packages/linux/install.sh" ]]; then
  package_script="$fixture/repo/packages/linux/install.sh"
else
  package_script="$fixture/repo/packages/linux/core.sh"
fi
run_package() {
  local expected="$1" status=0; shift
  : > "$INSTALL_TEST_LOG"
  bash "$package_script" "$@" > "$fixture/packages.out" 2>&1 || status=$?
  [[ "$status" == "$expected" ]] || { cat "$fixture/packages.out" >&2; fail "package status $status, expected $expected"; }
}
run_package 0 --check
! grep -q '^sudo -n pacman' "$INSTALL_TEST_LOG" || fail 'check installed packages'
READINESS_EXIT=3 run_package 3
[[ ! -s "$INSTALL_TEST_LOG" ]] || fail 'commands ran after failed readiness'
DENY_SUDO=1 run_package 4
! grep -q '^sudo -n pacman' "$INSTALL_TEST_LOG" || fail 'packages ran without authorization'
run_package 0
grep -q '^sudo -n pacman -S --needed --noconfirm -- ' "$INSTALL_TEST_LOG" || fail 'missing noninteractive package transaction'
! grep -Eq -- '(-Sy|omarchy update)' "$INSTALL_TEST_LOG" || fail 'unattended package additions updated databases'
PACKAGE_EXIT=42 run_package 42
printf '%s\n' 'PASS: unattended package readiness, authorization, transaction, and failure propagation'
