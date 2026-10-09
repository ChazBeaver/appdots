#!/bin/sh
# herdr-workspace — create a Herdr workspace with the standard tab layout, or
# apply that layout to an existing workspace (e.g. one herdr made for a worktree).
#
#   herdr-workspace new [label]        create workspace in the active pane's cwd
#   herdr-workspace layout [ws-id]     ensure the standard tabs exist in a workspace
#   herdr-workspace worktree [branch] [base]  create a worktree with standard tabs
#   herdr-workspace open <path>        open a worktree with standard tabs
#
# Standard layout: first tab "chat" (agent), second tab "repo" (your shell).
# Bound in config/herdr/config.toml; run from a popup (new) or shell (layout).

set -eu

# Herdr runs custom commands with the server's environment, which can lack the
# user's shell PATH. Add the usual tool locations so herdr and jq resolve.
PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
export PATH

FIRST_TAB="chat"
EXTRA_TABS="repo"

hold() {
  if [ -t 0 ]; then
    printf '\nPress Enter to close.' >&2
    read -r _ || true
  fi
}

fail() {
  printf 'herdr-workspace: %s\n' "$1" >&2
  hold
  exit 1
}

usage() {
  printf 'Usage: herdr-workspace new [label] | layout [workspace-id] | worktree [branch] [base] | open <path>\n' >&2
  hold
  exit 2
}

for dependency in herdr jq; do
  command -v "$dependency" >/dev/null 2>&1 || fail "required command not found: $dependency"
done

cwd="${HERDR_ACTIVE_PANE_CWD:-$PWD}"

# apply_layout <workspace-id> <cwd>
# Renames the first tab to $FIRST_TAB when it still has its default numeric
# label, then creates any standard tabs that are missing. Never renames a tab
# the user has already named or duplicates an existing chat/repo tab.
apply_layout() {
  ws="$1"
  dir="$2"
  tabs="$(herdr tab list --workspace "$ws")" || fail "herdr tab list failed for $ws"

  first_id="$(printf '%s\n' "$tabs" | jq -r '.result.tabs | sort_by(.number) | .[0].tab_id // empty')"
  first_label="$(printf '%s\n' "$tabs" | jq -r '.result.tabs | sort_by(.number) | .[0].label // empty')"
  [ -n "$first_id" ] || fail "workspace $ws has no tabs"

  if ! printf '%s\n' "$tabs" | jq -e --arg n "$FIRST_TAB" '.result.tabs[] | select(.label == $n)' >/dev/null; then
    case "$first_label" in
      *[!0-9]*) ;;  # already named by the user, leave it
      *)
        herdr tab rename "$first_id" "$FIRST_TAB" >/dev/null || fail "could not rename first tab"
        tabs="$(herdr tab list --workspace "$ws")" || fail "could not refresh tabs"
        ;;
    esac
  fi

  for name in "$FIRST_TAB" $EXTRA_TABS; do
    if printf '%s\n' "$tabs" | jq -e --arg n "$name" '.result.tabs[] | select(.label == $n)' >/dev/null; then
      continue
    fi
    herdr tab create --workspace "$ws" --cwd "$dir" --label "$name" --no-focus >/dev/null \
      || fail "could not create tab $name"
  done
}

mode="${1:-}"
case "$mode" in
  new)
    label="${2:-}"
    default_label="$(basename "$cwd")"
    if [ -z "$label" ] && [ -t 0 ]; then
      printf 'workspace name [%s]: ' "$default_label"
      read -r label || label=""
    fi
    [ -n "$label" ] || label="$default_label"

    created="$(herdr workspace create --cwd "$cwd" --label "$label" --no-focus)" \
      || fail "herdr workspace create failed"
    ws="$(printf '%s\n' "$created" | jq -r '.result.workspace.workspace_id // empty')"
    [ -n "$ws" ] || fail "no workspace id in response: $created"

    apply_layout "$ws" "$cwd"
    herdr workspace focus "$ws" >/dev/null || true
    ;;
  layout)
    ws="${2:-${HERDR_ACTIVE_WORKSPACE_ID:-${HERDR_WORKSPACE_ID:-}}}"
    [ -n "$ws" ] || fail "no workspace id (pass one, or run from inside Herdr)"
    apply_layout "$ws" "$cwd"
    ;;
  worktree|open)
    [ "${HERDR_ENV:-}" = 1 ] || fail "run this command inside Herdr"
    command -v git >/dev/null 2>&1 || fail "required command not found: git"
    repo="$(git -C "$cwd" rev-parse --show-toplevel)" || fail "not a Git checkout: $cwd"
    if [ "$mode" = worktree ]; then
      [ "$#" -le 3 ] || usage
      branch="${2:-}"
      base="${3:-}"
      if [ -z "$branch" ] && [ -t 0 ]; then
        printf 'branch (e.g. feature/my-change): '
        read -r branch || exit 0
        [ -n "$branch" ] || exit 0
      fi
      [ -n "$branch" ] || usage
      git check-ref-format --branch "$branch" >/dev/null || fail "invalid branch: $branch"
      set -- worktree create --cwd "$repo" --branch "$branch" --no-focus
      [ -z "$base" ] || set -- "$@" --base "$base"
    else
      [ "$#" -eq 2 ] && [ -n "$2" ] || usage
      set -- worktree open --cwd "$repo" --path "$2" --no-focus
    fi
    opened="$(herdr "$@")" || fail "herdr $1 $2 failed"
    ws="$(printf '%s\n' "$opened" | jq -r '.result.workspace.workspace_id // empty')"
    checkout="$(printf '%s\n' "$opened" | jq -r '.result.worktree.path // empty')"
    [ -n "$ws" ] && [ -n "$checkout" ] || fail "missing worktree path or workspace id in response: $opened"
    apply_layout "$ws" "$checkout"
    herdr workspace focus "$ws" >/dev/null || fail "could not focus workspace $ws"
    ;;
  *) usage ;;
esac
