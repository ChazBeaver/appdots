#!/usr/bin/env bash
# Preconditions for package additions on a system prepared by the caller.
# Exit 3 means a reboot is required; 4 means an unmet prerequisite.
unattended_linux_ready() {
  local user_home="${1:-$HOME}" modules="${2:-/usr/lib/modules}" output rc=0
  output="$(pacman -Qu 2>&1)" || rc=$?
  if [[ -n "$output" || "$rc" -gt 1 ]]; then
    printf '%s\n' 'Complete the supported system update before unattended installation (omarchy update on Omarchy; pacman -Syu on Arch).' >&2
    return 4
  fi
  if [[ -f "$user_home/.local/state/omarchy/reboot-required" ]]; then
    printf '%s\n' 'Reboot before unattended installation.' >&2; return 3
  fi
  local kernel running seen=false matched=false
  running="$(uname -r)" || return 4
  for kernel in "$modules"/*/vmlinuz; do
    [[ -f "$kernel" ]] || continue
    pacman -Qo "$kernel" >/dev/null 2>&1 || continue
    seen=true
    [[ "$(basename "$(dirname "$kernel")")" != "$running" ]] || matched=true
  done
  if [[ "$seen" == true && "$matched" == false ]]; then
    printf '%s\n' 'The installed kernel differs from the running kernel; reboot first.' >&2; return 3
  fi
  local pid executable
  if command -v pgrep >/dev/null 2>&1; then
    for pid in $(pgrep -x Hyprland || true); do
      executable="$(readlink "/proc/$pid/exe" 2>/dev/null || true)"
      if [[ "$executable" == *' (deleted)' ]]; then
        printf '%s\n' 'Restart the desktop session after the system update.' >&2; return 3
      fi
    done
  fi
  return 0
}
