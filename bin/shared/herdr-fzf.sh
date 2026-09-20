#!/bin/sh

set -eu

usage() {
  printf 'Usage: herdr-fzf <tab|workspace>\n' >&2
  exit 2
}

mode="${1:-}"
case "$mode" in
  tab | workspace) ;;
  *) usage ;;
esac

for dependency in herdr jq fzf; do
  if ! command -v "$dependency" >/dev/null 2>&1; then
    printf 'herdr-fzf: required command not found: %s\n' "$dependency" >&2
    exit 1
  fi
done

snapshot="$(herdr api snapshot)"

case "$mode" in
  tab)
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
esac

[ -n "$rows" ] || exit 0

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
esac
