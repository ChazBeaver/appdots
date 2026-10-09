# Appdots function registry and interactive command palette.
#
# Public functions register themselves after their definitions. This keeps the
# help text next to the code it documents while allowing one searchable view of
# every appdots function loaded on the current platform.

zmodload zsh/parameter 2>/dev/null || true

# Preserve registrations from other modules when reloading just the help UI.
typeset -gA _AD_FN_GROUP
typeset -gA _AD_FN_USAGE
typeset -gA _AD_FN_DESCRIPTION
typeset -gA _AD_FN_EFFECT
typeset -gA _AD_FN_LEGACY
typeset -gA _AD_FN_SOURCE
typeset -gA _AD_FN_EXAMPLE
typeset -gA _AD_FN_OWNED

# Description before the first semicolon is the picker label. The optional
# seventh argument is a printable example; omitted examples fall back to usage.
_ad_register() {
  emulate -L zsh

  local name="$1"
  local group="$2"
  local usage="$3"
  local description="$4"
  local effect="${5:-run}"
  local legacy="${6:-}"
  local example="${7:-$usage}"
  local source="${functions_source[$name]:-}"

  _AD_FN_GROUP[$name]="$group"
  _AD_FN_USAGE[$name]="$usage"
  _AD_FN_DESCRIPTION[$name]="$description"
  _AD_FN_EFFECT[$name]="$effect"
  _AD_FN_LEGACY[$name]="$legacy"
  _AD_FN_SOURCE[$name]="$source"
  _AD_FN_EXAMPLE[$name]="$example"
  if [[ -n "$source" && "${source:A}" == "$_AD_FN_MODULE_ROOT/"* ]]; then
    _AD_FN_OWNED[$name]=1
  else
    unset "_AD_FN_OWNED[$name]"
  fi
}

# Only functions defined by this managed module tree belong in the palette.
# Resolve symlinks now; modules can be sourced through ~/zsh_modules.
typeset -g _AD_FN_MODULE_ROOT="${${functions_source[_ad_register]}:A:h:h}"

# Keep existing appdots registrations visible when only this module is reloaded.
for _ad_fn_name in ${(k)_AD_FN_SOURCE}; do
  _ad_fn_source="${_AD_FN_SOURCE[$_ad_fn_name]}"
  if [[ -n "$_ad_fn_source" && "${_ad_fn_source:A}" == "$_AD_FN_MODULE_ROOT/"* && \
        "${functions_source[$_ad_fn_name]:-}" == "$_ad_fn_source" ]]; then
    _AD_FN_OWNED[$_ad_fn_name]=1
  else
    unset "_AD_FN_OWNED[$_ad_fn_name]"
  fi
done
unset _ad_fn_name _ad_fn_source

_ad_fn_owned() {
  local name="$1"
  [[ "${_AD_FN_OWNED[$name]:-0}" == 1 ]] &&
    (( ${+functions[$name]} )) &&
    [[ "${functions_source[$name]:-}" == "${_AD_FN_SOURCE[$name]}" ]]
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
  local current_group haystack token

  current_group="${_AD_FN_GROUP[$name]}"
  if [[ -n "$group" && "$current_group" != "$group" && "$current_group" != "$group/"* ]]; then
    return 1
  fi
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
  local entry name badge description
  local -a entries

  for name in "${(k)_AD_FN_DESCRIPTION[@]}"; do
    entries+=("${_AD_FN_GROUP[$name]}:$name")
  done

  for entry in "${(on)entries[@]}"; do
    name="${entry#*:}"
    _ad_fn_owned "$name" || continue
    _ad_fn_matches "$name" "$group" "$query" || continue
    badge="$(_ad_fn_badge "${_AD_FN_EFFECT[$name]}")"
    description="${_AD_FN_DESCRIPTION[$name]}"
    # The first clause is the compact label; retain full metadata for search.
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$badge" \
      "${_AD_FN_GROUP[$name]}" \
      "$name" \
      "${_AD_FN_USAGE[$name]}" \
      "$description" \
      "${_AD_FN_LEGACY[$name]:--}" \
      "${_AD_FN_SOURCE[$name]:--}" \
      "${description%%;*}"
  done
}

_ad_fn_list() {
  emulate -L zsh

  local group="$1"
  local query="$2"
  local row line prefix
  local -i columns=${COLUMNS:-0}
  (( columns > 0 )) || columns=80
  local -i width=$(( columns - 35 ))
  (( width >= 20 )) || width=20
  local -a fields

  printf '%-2s  %-12s  %-15s  %s\n' "" "GROUP" "FUNCTION" "DESCRIPTION"
  while IFS= read -r row; do
    fields=( "${(@ps:\t:)row}" )
    prefix="$(printf '%-2s  %-12s  %-15s  ' "$fields[1]" "$fields[2]" "$fields[3]")"
    while IFS= read -r line; do
      print -r -- "$prefix$line"
      prefix="$(printf '%35s' '')"
    done < <(print -r -- "$fields[5]" | fold -s -w "$width")
  done < <(_ad_fn_rows "$group" "$query")
}

_ad_fn_show() {
  emulate -L zsh

  local name="$1"
  local source="${_AD_FN_SOURCE[$name]:-unknown}"

  if ! _ad_fn_owned "$name"; then
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

_ad_fn_example() {
  emulate -L zsh
  local name="$1"
  _ad_fn_owned "$name" || return 1
  print -r -- "${_AD_FN_EXAMPLE[$name]:-${_AD_FN_USAGE[$name]}}"
}

_ad_fn_picker() {
  emulate -L zsh
  local group="$1" query="$2" input search_command
  local -a search_options
  [[ "${_AD_FN_CONTEXT_EXACT:-0}" == 1 ]] && search_options+=(--exact)

  # fzf searches its transformed display. Filter the full snapshot separately
  # so usage, detailed descriptions and former names need not clutter the UI.
  input="$(mktemp "${TMPDIR:-/tmp}/appdots-functions.XXXXXXXX")" || return 1
  {
    _ad_fn_rows "$group" '' > "$input" || return 1
    search_command="FZF_DEFAULT_OPTS= FZF_DEFAULT_OPTS_FILE= ${(q)commands[fzf]} ${(j: :)search_options} --delimiter='\t' --nth=2..6 --filter={q} < ${(q)input} || test \$? -eq 1"
    command fzf \
      +m --disabled \
      --delimiter=$'\t' \
      --with-nth=1,3,2,8 \
      --tabstop=2 --no-wrap --no-hscroll \
      --prompt='fn> ' \
      --query="$query" \
      --header='ctrl-e: example  ctrl-f: function' \
      --expect=ctrl-e,ctrl-f \
      --bind="start:reload-sync($search_command),change:reload-sync($search_command)" \
      --bind='?:toggle-preview' \
      --preview-window='down,35%,wrap,hidden' \
      --preview='printf "Usage:\n  %s\n\nDescription:\n  %s\n\nAliases / former names:\n  %s\n\nSource:\n  %s\n" {4} {5} {6} {7}' \
      < /dev/null
  } always {
    command rm -f -- "$input"
  }
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
  fn --group GROUP [QUERY]      Search within a function group or group prefix.
  fn --list [QUERY]             Print matching functions without fzf.
  fn --source FUNCTION          Print a function's live definition.

Palette keys:
  enter    Insert the selected function into the command prompt.
  ctrl-e   Close the palette and explain the selected function.
  ctrl-f   Close the palette and show its definition and source.
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

  output="$(_ad_fn_picker "$group" "$query")" || return 0

  key="${output%%$'\n'*}"
  selected="${output#*$'\n'}"
  [[ -n "$selected" && "$selected" != "$output" ]] || return 0

  fields=( "${(@ps:\t:)selected}" )
  name="$fields[3]"
  [[ -n "$name" ]] || return 0

  if [[ "$key" == "ctrl-e" ]]; then
    _ad_fn_example "$name"
  elif [[ "$key" == "ctrl-f" ]]; then
    _ad_fn_show "$name"
  elif [[ -o interactive ]]; then
    print -z -- "$name "
  else
    print -r -- "$name"
  fi
}

_ad_register fn help 'fn [QUERY]' 'Browse, inspect, and insert appdots functions.' view list-functions \
    'When: You know a task, but you do not know its function name.
Example:
  fn directory
Result: The picker lists functions that match "directory".
Press Ctrl-E for an example. Press Ctrl-F for the function source.
Press Enter to put the selected name at your prompt.'
