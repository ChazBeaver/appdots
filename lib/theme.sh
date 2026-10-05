#!/usr/bin/env bash
# Shared macOS palette rendering. Source this; do not execute.
# Depends on lib/log.sh. Uses no desktop state and works with Bash 3.2 callers.

find_bash4() {
  local candidate
  for candidate in "$(command -v bash || true)" /opt/homebrew/bin/bash /usr/local/bin/bash; do
    [ -n "$candidate" ] && [ -x "$candidate" ] || continue
    "$candidate" -c '(( BASH_VERSINFO[0] >= 4 ))' 2>/dev/null && { printf '%s' "$candidate"; return 0; }
  done
  return 1
}

# render_theme_templates COLORS TEMPLATES OUTPUT RESOLVER BASH4
# OUTPUT must already exist. Only palette hex colors become template values.
render_theme_templates() (
  local colors="$1" templates="$2" output="$3" resolver="$4" resolver_bash="$5"
  local work key value tpl name
  [ -f "$colors" ] && [ ! -L "$colors" ] || {
    log_err "Missing or symlinked palette: $colors"
    return 1
  }
  for name in ghostty.conf neovim.lua; do
    [ -f "$templates/$name.tpl" ] || {
      log_err "Missing template: $templates/$name.tpl"
      return 1
    }
  done
  work="$(mktemp -d)" || return 1
  trap 'rm -rf -- "$work"' EXIT
  "$resolver_bash" "$resolver" --file "$colors" --all > "$work/colors" || {
    log_err "Could not resolve palette: $colors"
    return 1
  }
  : > "$work/substitutions"
  while IFS=$'\t' read -r key value; do
    [[ $key =~ ^[A-Za-z0-9_]+$ && $value =~ ^#[0-9A-Fa-f]{6}$ ]] || continue
    printf 's|{{ %s }}|%s|g\n' "$key" "$value" >> "$work/substitutions"
    printf 's|{{ %s_strip }}|%s|g\n' "$key" "${value#\#}" >> "$work/substitutions"
  done < "$work/colors"

  for tpl in "$templates"/*.tpl; do
    name="$(basename "$tpl" .tpl)"
    sed -f "$work/substitutions" "$tpl" > "$output/$name" || return 1
    if grep -q '{{' "$output/$name"; then
      log_err "Unresolved palette value in $name from $colors"
      return 1
    fi
  done
)
