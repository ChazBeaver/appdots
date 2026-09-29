#!/usr/bin/env bash
set -euo pipefail
# appdots/doctor/herdr-integrations.sh
# Verify the Herdr agent integrations declared in integrations/herdr.sh are
# installed and still at the version that was reviewed. Read-only.
#
# Drift this catches:
#   - a declared agent exists here but has no herdr hook       → run bootstrap
#   - herdr rewrote a hook to a version nobody has read yet   → review + bump pin
#   - herdr has a newer hook template than what is installed  → review + reinstall + bump pin

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-${(%):-%N}}")" &>/dev/null && pwd)"
APPDOTS_DIR="$(cd -- "$SCRIPT_DIR/.." &>/dev/null && pwd)"

# shellcheck source=../lib/log.sh
source "$APPDOTS_DIR/lib/log.sh"
# shellcheck source=../lib/herdr.sh
source "$APPDOTS_DIR/lib/herdr.sh"
# shellcheck source=../integrations/herdr.sh
source "$APPDOTS_DIR/integrations/herdr.sh"

echo
log_info "Herdr agent integrations check"
echo

if ! command -v herdr >/dev/null 2>&1; then
  log_info "herdr not installed — nothing to check."
  exit 0
fi

status=0
for entry in "${HERDR_INTEGRATIONS[@]}"; do
  agent="${entry%%=*}"
  pinned="${entry#*=}"

  if ! herdr_agent_detected "$agent"; then
    log_info "$agent: not on this machine — skipped."
    continue
  fi

  IFS="$HERDR_FS" read -r state version path < <(herdr_integration_status "$agent")

  case "$state" in
    "not installed")
      log_err "$agent: herdr integration not installed. Run ./bootstrap.sh (or system/shared/20-herdr-integrations.sh)."
      status=1
      ;;
    current)
      if [ "$version" = "$pinned" ]; then
        log_ok "$agent: v$version installed and reviewed."
      else
        log_err "$agent: installed v$version but the reviewed pin is v$pinned."
        echo "     Review $path, then set \"$agent=$version\" in integrations/herdr.sh."
        status=1
      fi
      ;;
    unknown)
      log_err "$agent: not listed by 'herdr integration status'. Is the id in integrations/herdr.sh correct?"
      status=1
      ;;
    *)
      log_warn "$agent: herdr reports '$state' (installed v${version:-?}, reviewed pin v$pinned)."
      echo "     herdr wants to upgrade this hook. Review the new version, then run:"
      echo "       herdr integration install $agent"
      echo "     and update the pin in integrations/herdr.sh."
      status=1
      ;;
  esac
done

exit "$status"
