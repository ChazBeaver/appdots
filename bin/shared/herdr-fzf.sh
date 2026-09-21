#!/bin/sh

set -eu

# Popups close the moment this script exits, so a failure message would vanish
# unread. Hold the popup open until a key is pressed when stdin is a terminal.
hold() {
  if [ -t 0 ]; then
    printf '\nPress Enter to close.' >&2
    read -r _ || true
  fi
}

fail() {
  printf 'herdr-fzf: %s\n' "$1" >&2
  hold
  exit 1
}

usage() {
  printf 'Usage: herdr-fzf <tab|workspace|worktree>\n' >&2
  hold
  exit 2
}

mode="${1:-}"
case "$mode" in
  tab | workspace | worktree) ;;
  *) usage ;;
esac

for dependency in herdr jq fzf; do
  if ! command -v "$dependency" >/dev/null 2>&1; then
    fail "required command not found: $dependency (PATH=$PATH)"
  fi
done

case "$mode" in
  tab)
    snapshot="$(herdr api snapshot)" || fail "herdr api snapshot failed"
    rows="$(
      printf '%s\n' "$snapshot" | jq -r '
        .result.snapshot as $snapshot
        | ($snapshot.workspaces
          | map({ key: .workspace_id, value: .label })
          | from_entries) as $workspace_labels
        | $snapshot.tabs[]
        | [
            .tab_id,
            ($workspace_labels[.workspace_id] // .workspace_id),
            .label,
            .agent_status,
            ("panes:" + (.pane_count | tostring))
          ]
        | @tsv
      '
    )"
    prompt='tab> '
    header='workspace  tab  status  panes'
    ;;
  workspace)
    snapshot="$(herdr api snapshot)" || fail "herdr api snapshot failed"
    rows="$(
      printf '%s\n' "$snapshot" | jq -r '
        .result.snapshot.workspaces[]
        | [
            .workspace_id,
            .label,
            .agent_status,
            ("tabs:" + (.tab_count | tostring)),
            ("panes:" + (.pane_count | tostring))
          ]
        | @tsv
      '
    )"
    prompt='workspace> '
    header='workspace  status  tabs  panes'
    ;;
  worktree)
    # herdr exits nonzero on an API error and prints the JSON error to stderr.
    listing="$(herdr worktree list --cwd "$PWD" 2>&1 || true)"
    [ -n "$listing" ] || fail "herdr worktree list produced no output"
    error_message="$(printf '%s\n' "$listing" | jq -r '.error.message // empty')"
    [ -z "$error_message" ] || fail "$error_message"
    rows="$(
      printf '%s\n' "$listing" | jq -r '
        .result.worktrees[]
        | [
            .path,
            .label,
            (if .is_detached then "detached" else .branch end),
            (if .is_linked_worktree then "worktree" else "main checkout" end),
            .path
          ]
        | @tsv
      '
    )"
    prompt='worktree> '
    header='label  branch  kind  path'
    ;;
esac

[ -n "$rows" ] || fail "no ${mode}s found (herdr $(herdr --version 2>&1 | tail -n1))"

tab_character="$(printf '\t')"
choice="$(
  printf '%s\n' "$rows" | fzf \
    --delimiter="$tab_character" \
    --with-nth='2..' \
    --accept-nth=1 \
    --ignore-case \
    +m \
    --layout=reverse \
    --border=rounded \
    --info=inline \
    --prompt="$prompt" \
    --header="$header"
)" || exit 0

[ -n "$choice" ] || exit 0
target_id="$choice"

case "$mode" in
  tab) exec herdr tab focus "$target_id" ;;
  workspace) exec herdr workspace focus "$target_id" ;;
  worktree) exec herdr worktree open --cwd "$PWD" --path "$target_id" --focus ;;
esac
