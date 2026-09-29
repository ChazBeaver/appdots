#!/usr/bin/env bash
set -euo pipefail
# appdots/system/shared/20-herdr-integrations.sh
# Install Herdr's agent integrations (session-start hooks / plugins) for the
# agents declared in integrations/herdr.sh.
#
# Why a script and not a symlinked config:
#   - herdr generates and version-stamps the hook files and overwrites them on
#     reinstall, so committing them would only drift from what herdr ships.
#   - the install also merges entries into files appdots does not own
#     (~/.claude/settings.json, ~/.codex/config.toml, ~/.config/opencode/tui.jsonc)
#     and writes absolute paths into them.
#
# Safety: only MISSING integrations are installed. An installed hook is never
# rewritten here, so a herdr upgrade cannot silently replace code that runs at
# every agent session start. doctor/herdr-integrations.sh reports when herdr
# wants to upgrade one; review it, then upgrade by hand (README → "Herdr agent
# integrations").
#
# bootstrap.sh runs a temp copy of this file, so the repo is located through
# APP_DOTS_DIR (exported by bootstrap) rather than relative to the script.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-${(%):-%N}}")" &>/dev/null && pwd)"
APPDOTS_DIR="${APP_DOTS_DIR:-$(cd -- "$SCRIPT_DIR/../.." &>/dev/null && pwd)}"

# shellcheck source=../../lib/herdr.sh
source "$APPDOTS_DIR/lib/herdr.sh"
# shellcheck source=../../integrations/herdr.sh
source "$APPDOTS_DIR/integrations/herdr.sh"

if ! command -v herdr >/dev/null 2>&1; then
  echo "⚠️  herdr not installed — skipping agent integrations"
  exit 0
fi

for entry in "${HERDR_INTEGRATIONS[@]}"; do
  agent="${entry%%=*}"
  pinned="${entry#*=}"

  if ! herdr_agent_detected "$agent"; then
    echo "  – $agent: not on this machine — skipping (re-run after installing it)"
    continue
  fi

  IFS="$HERDR_FS" read -r state version path < <(herdr_integration_status "$agent")

  case "$state" in
    "not installed")
      echo "  + $agent: installing herdr integration"
      herdr integration install "$agent"
      IFS="$HERDR_FS" read -r state version path < <(herdr_integration_status "$agent")
      if [ "$state" != "current" ]; then
        echo "  ⚠️  $agent: install did not converge — herdr reports '$state'"
      elif [ "$version" != "$pinned" ]; then
        echo "  ⚠️  $agent: herdr installed v$version but integrations/herdr.sh pins v$pinned"
        echo "      Review $path, then update the pin."
      else
        echo "  ✓ $agent: installed v$version (matches reviewed pin)"
      fi
      ;;
    current)
      echo "  ✓ $agent: v$version already installed"
      ;;
    unknown)
      echo "  ⚠️  $agent: not known to this herdr version — check integrations/herdr.sh"
      ;;
    *)
      echo "  ⚠️  $agent: herdr reports '$state' (v${version:-?}) — left untouched"
      echo "      Review before upgrading: README → Herdr agent integrations"
      ;;
  esac
done
