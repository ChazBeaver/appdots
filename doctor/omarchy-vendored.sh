#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
# appdots/doctor/omarchy-vendored.sh
# The macOS theme command (bin/macos/theme.sh) relies on verbatim copies of
# Omarchy's palette resolver and two of its templates. This check compares
# each copy against the original under /usr/share/omarchy so an Omarchy
# update that changes one shows up as drift here instead of silently
# diverging on the Mac. Read-only. Only meaningful where Omarchy is
# installed; elsewhere it reports nothing to check.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-${(%):-%N}}")" &>/dev/null && pwd)"
APPDOTS_DIR="$(cd -- "$SCRIPT_DIR/.." &>/dev/null && pwd)"

# shellcheck source=../lib/log.sh
source "$APPDOTS_DIR/lib/log.sh"

OMARCHY="${OMARCHY_PATH:-/usr/share/omarchy}"
DRIFT=0

log_info "Vendored Omarchy theme files check"

if [ ! -d "$OMARCHY" ]; then
  log_info "Omarchy not installed here; nothing to compare against."
  exit 0
fi

# original<TAB>vendored copy (repo-relative)
PAIRS=(
  "$OMARCHY/bin/omarchy-theme-color	bin/macos/omarchy-theme-color.sh"
  "$OMARCHY/default/themed/ghostty.conf.tpl	active/macos/.config/omarchy/themed/ghostty.conf.tpl"
  "$OMARCHY/default/themed/neovim.lua.tpl	active/macos/.config/omarchy/themed/neovim.lua.tpl"
)

for pair in "${PAIRS[@]}"; do
  original="${pair%%	*}"
  copy="$APPDOTS_DIR/${pair#*	}"
  if [ ! -f "$original" ]; then
    log_warn "Original missing (Omarchy layout changed?): $original"
    DRIFT=1
    continue
  fi
  if [ ! -f "$copy" ]; then
    log_err "Vendored copy missing: $copy"
    log_info "Fix: cp $original $copy"
    DRIFT=1
    continue
  fi
  if cmp -s "$original" "$copy"; then
    log_ok "Up to date: ${pair#*	}"
  else
    log_err "Differs from Omarchy: ${pair#*	}"
    log_info "Fix (after reviewing the diff): cp $original $copy"
    DRIFT=1
  fi
done

# The Mac's palettes are copies of the themes installed here: the user's
# under ~/.config/omarchy/themes and Omarchy's own under $OMARCHY/themes
# (the two places omarchy-theme-list reads). Report any palette that no
# longer matches its Linux counterpart, and any installed theme with a
# palette that the Mac does not carry (informational).
MAC_THEMES="$APPDOTS_DIR/active/macos/.config/omarchy/themes"
USER_THEMES="$HOME/.config/omarchy/themes"
SYSTEM_THEMES="$OMARCHY/themes"

# linux_palette <slug>: print the installed colors.toml for a slug, user first.
linux_palette() {
  local dir
  for dir in "$USER_THEMES" "$SYSTEM_THEMES"; do
    if [ -f "$dir/$1/colors.toml" ]; then
      printf '%s\n' "$dir/$1/colors.toml"
      return 0
    fi
  done
  return 1
}

MISSING=0
if [ -d "$MAC_THEMES" ]; then
  for dir in "$MAC_THEMES"/*/; do
    slug="$(basename "$dir")"
    if ! linux="$(linux_palette "$slug")"; then
      log_warn "Palette $slug is on the Mac but not installed here (kept as is)"
      continue
    fi
    if ! cmp -s "$linux" "$dir/colors.toml"; then
      log_err "Palette differs from the installed Linux theme: $slug"
      log_info "Fix (after reviewing the diff): cp $linux $dir/colors.toml"
      DRIFT=1
    fi
  done
  for src in "$USER_THEMES" "$SYSTEM_THEMES"; do
    [ -d "$src" ] || continue
    for dir in "$src"/*/; do
      slug="$(basename "$dir")"
      [ -f "$dir/colors.toml" ] || continue
      if [ ! -d "$MAC_THEMES/$slug" ]; then
        log_info "Not carried for the Mac: $slug (add with: mkdir -p $MAC_THEMES/$slug && cp $dir/colors.toml $MAC_THEMES/$slug/)"
        MISSING=$((MISSING + 1))
      fi
    done
  done
fi

if [ "$DRIFT" -ne 0 ]; then
  exit 1
fi
log_ok "Vendored Omarchy theme files and Mac palettes match the installed originals."
