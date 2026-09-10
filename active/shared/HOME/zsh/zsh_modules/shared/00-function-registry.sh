# Appdots function registry and interactive command palette.
#
# Public functions register themselves after their definitions. This keeps the
# help text next to the code it documents while allowing one searchable view of
# every appdots function loaded on the current platform.

zmodload zsh/parameter 2>/dev/null || true

typeset -gA _AD_FN_GROUP=()
typeset -gA _AD_FN_USAGE=()
typeset -gA _AD_FN_DESCRIPTION=()
typeset -gA _AD_FN_EFFECT=()
typeset -gA _AD_FN_LEGACY=()
typeset -gA _AD_FN_SOURCE=()

_ad_register() {
  emulate -L zsh

  local name="$1"
  local group="$2"
  local usage="$3"
  local description="$4"
  local effect="${5:-run}"
  local legacy="${6:-}"

  _AD_FN_GROUP[$name]="$group"
  _AD_FN_USAGE[$name]="$usage"
  _AD_FN_DESCRIPTION[$name]="$description"
  _AD_FN_EFFECT[$name]="$effect"
  _AD_FN_LEGACY[$name]="$legacy"
  _AD_FN_SOURCE[$name]="${functions_source[$name]:-}"
}

_ad_fn_badge() {
  case "$1" in
    view)   print -r -- "○" ;;
    danger) print -r -- "⚠" ;;
    *)      print -r -- "●" ;;
  esac
}

_ad_fn_matches() {
  emulate -L zsh

  local name="$1"
  local group="$2"
  local query="$3"
  local haystack token

  [[ -n "$group" && "${_AD_FN_GROUP[$name]}" != "$group" ]] && return 1
  [[ -z "$query" ]] && return 0

  haystack="${name} ${_AD_FN_GROUP[$name]} ${_AD_FN_USAGE[$name]} ${_AD_FN_DESCRIPTION[$name]} ${_AD_FN_LEGACY[$name]}"
  haystack="${haystack:l}"

  for token in ${(z)query}; do
    token="${token:l}"
    [[ "$haystack" == *"$token"* ]] || return 1
  done
}

_ad_fn_rows() {
  emulate -L zsh

  local group="$1"
  local query="$2"
  local name badge
  local -a names

  names=( ${(ok)_AD_FN_DESCRIPTION} )
  for name in "${names[@]}"; do
    (( ${+functions[$name]} )) || continue
    _ad_fn_matches "$name" "$group" "$query" || continue
    badge="$(_ad_fn_badge "${_AD_FN_EFFECT[$name]}")"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$badge" \
      "${_AD_FN_GROUP[$name]}" \
      "$name" \
      "${_AD_FN_USAGE[$name]}" \
      "${_AD_FN_DESCRIPTION[$name]}" \
      "${_AD_FN_LEGACY[$name]:--}" \
      "${_AD_FN_SOURCE[$name]:--}"
  done
}

_ad_fn_list() {
  emulate -L zsh

  local group="$1"
  local query="$2"
  local row
  local -a fields

  printf '%-2s  %-12s  %-15s  %s\n' "" "GROUP" "FUNCTION" "DESCRIPTION"
  while IFS= read -r row; do
    fields=( "${(@ps:\t:)row}" )
    printf '%-2s  %-12s  %-15s  %s\n' \
      "$fields[1]" "$fields[2]" "$fields[3]" "$fields[5]"
  done < <(_ad_fn_rows "$group" "$query")
}

_ad_fn_show() {
  emulate -L zsh

  local name="$1"
  local source="${_AD_FN_SOURCE[$name]:-unknown}"

  if (( ! ${+functions[$name]} )); then
    print -u2 -- "Unknown appdots function: $name"
    return 1
  fi

  print -P "%F{cyan}$name%f  %F{white}$source%f"
  print

  if (( $+commands[bat] )); then
    functions "$name" | command bat --language=zsh --style=plain --paging=auto
  else
    functions "$name"
  fi
}

fn() {
  emulate -L zsh

  local mode="pick"
  local group=""
  local query=""
  local source_name=""
  local arg output key selected name
  local -a fields

  while (( $# )); do
    arg="$1"
    shift
    case "$arg" in
      -l|--list)
        mode="list"
        ;;
      -g|--group)
        if (( ! $# )); then
          print -u2 -- "Usage: fn [--list] [--group GROUP] [QUERY]"
          return 1
        fi
        group="$1"
        shift
        ;;
      -s|--source)
        if (( ! $# )); then
          print -u2 -- "Usage: fn --source FUNCTION"
          return 1
        fi
        mode="source"
        source_name="$1"
        shift
        ;;
      -h|--help)
        cat <<'EOF'
Usage:
  fn [QUERY]                    Search appdots functions with fzf.
  fn --group GROUP [QUERY]      Search within one function group.
  fn --list [QUERY]             Print matching functions without fzf.
  fn --source FUNCTION          Print a function's live definition.

Palette keys:
  enter    Insert the selected function into the command prompt.
  ctrl-e   Close the palette and show its definition and source.
  ?        Toggle the help preview.
  esc      Cancel without changing the prompt.

Badges:
  ○ read-only    ● changes state/context    ⚠ destructive or bulk
EOF
        return 0
        ;;
      --)
        query+="${query:+ }$*"
        break
        ;;
      *)
        query+="${query:+ }$arg"
        ;;
    esac
  done

  case "$mode" in
    source)
      _ad_fn_show "$source_name"
      return
      ;;
    list)
      _ad_fn_list "$group" "$query"
      return
      ;;
  esac

  if (( ! $+commands[fzf] )); then
    print -u2 -- "fzf not found; showing the printable function list instead."
    _ad_fn_list "$group" "$query"
    return 0
  fi

  output="$(
    _ad_fn_rows "$group" "" \
      | command fzf \
          +m \
          --delimiter=$'\t' \
          --with-nth=1,2,3,5 \
          --nth=2,3,4,5,6 \
          --prompt='fn> ' \
          --query="$query" \
          --header='enter: insert  ctrl-e: source  ?: preview  esc: cancel' \
          --expect=ctrl-e \
          --bind='?:toggle-preview' \
          --preview-window='right,55%,wrap' \
          --preview='printf "Usage:\n  %s\n\nDescription:\n  %s\n\nAliases / former names:\n  %s\n\nSource:\n  %s\n" {4} {5} {6} {7}'
  )" || return 0

  key="${output%%$'\n'*}"
  selected="${output#*$'\n'}"
  [[ -n "$selected" && "$selected" != "$output" ]] || return 0

  fields=( "${(@ps:\t:)selected}" )
  name="$fields[3]"
  [[ -n "$name" ]] || return 0

  if [[ "$key" == "ctrl-e" ]]; then
    _ad_fn_show "$name"
  elif [[ -o interactive ]]; then
    print -z -- "$name "
  else
    print -r -- "$name"
  fi
}

_ad_register fn help 'fn [QUERY]' 'Browse, inspect, and insert appdots functions.' view 'list-functions'
