#!/usr/bin/env bash
# appdots/lib/herdr.sh
# Helpers for Herdr agent integrations. Source this; do not execute.
# Shared by system/shared/20-herdr-integrations.sh and doctor/herdr-integrations.sh.

# herdr_agent_detected <agent>
# True when the agent's CLI is on PATH. Integrations are only installed and
# checked for agents that actually exist on this machine.
herdr_agent_detected() {
  command -v "$1" >/dev/null 2>&1
}

# herdr_integration_status <agent>
# Parses one line of `herdr integration status`, e.g.
#   claude: current (v8) (/home/me/.claude/hooks/herdr-agent-state.sh)
#   pi: not installed (/home/me/.pi/agent/extensions/herdr-agent-state.ts)
# Prints three fields separated by HERDR_FS: <state> <version> <path>.
# <state> is herdr's own word(s) ("current", "not installed", ...) or "unknown"
# when herdr does not list the agent. <version> is empty when not installed.
# The separator is a non-whitespace byte so `read` keeps empty fields intact.
HERDR_FS=$'\x1f'

herdr_integration_status() {
  local agent="$1" line rest state version="" path=""

  line="$(herdr integration status 2>/dev/null | grep -E "^${agent}: " || true)"
  if [ -z "$line" ]; then
    printf 'unknown%s%s\n' "$HERDR_FS" "$HERDR_FS"
    return 0
  fi

  rest="${line#*: }"
  state="${rest%% (*}"
  case "$rest" in
    *"(v"*) version="${rest#*(v}"; version="${version%%)*}" ;;
  esac
  path="${rest##*(}"
  path="${path%)}"

  printf '%s%s%s%s%s\n' "$state" "$HERDR_FS" "$version" "$HERDR_FS" "$path"
}
