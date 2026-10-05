#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
# Check macOS palette coverage and the actual Ghostty/Neovim rendering path.
# Palette differences and upstream resolver/template changes are not drift.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
APPDOTS_DIR="$(cd -- "$SCRIPT_DIR/.." &>/dev/null && pwd)"
source "$APPDOTS_DIR/lib/log.sh"
source "$APPDOTS_DIR/lib/theme.sh"

OMARCHY="${OMARCHY_PATH:-/usr/share/omarchy}"
MAC_THEMES="$APPDOTS_DIR/active/macos/.config/omarchy/themes"
USER_THEMES="${APPDOTS_LINUX_THEMES_DIR:-$HOME/.config/omarchy/themes}"
TEMPLATES="$APPDOTS_DIR/active/macos/.config/omarchy/themed"
RESOLVER="$APPDOTS_DIR/bin/macos/omarchy-theme-color.sh"
resolver_bash="$(find_bash4)" || { log_err "Install Bash 4+ (macOS: brew install bash)"; exit 1; }
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
DRIFT=0
count=0

log_info "macOS Ghostty and Neovim palette coverage check"

# A theme is covered when its Mac palette exists, regardless of color edits
# made independently on either platform. Extra Mac palettes remain usable.
if [ -d "$OMARCHY" ]; then
  for source in "$USER_THEMES" "$OMARCHY/themes"; do
    [ -d "$source" ] || continue
    for dir in "$source"/*/; do
      [ -f "$dir/colors.toml" ] || continue
      slug="$(basename "$dir")"
      if [ ! -f "$MAC_THEMES/$slug/colors.toml" ]; then
        log_err "Missing macOS palette for Linux theme: $slug"
        printf '  Fix: mkdir -p %q && cp %q %q\n' \
          "$MAC_THEMES/$slug" "$dir/colors.toml" "$MAC_THEMES/$slug/colors.toml"
        DRIFT=1
      fi
    done
  done
else
  log_info "Omarchy is not installed; checking the stored Mac palettes only"
fi

# Use the same renderer as theme set, without activating a theme or writing
# desktop state. The renderer requires both application templates and rejects
# unresolved colors; this catches missing/unusable palettes on either OS.
for dir in "$MAC_THEMES"/*/; do
  [ -d "$dir" ] || continue
  slug="$(basename "$dir")"
  count=$((count + 1))
  if ! render_theme_templates "$dir/colors.toml" "$TEMPLATES" "$work" "$RESOLVER" "$resolver_bash"; then
    log_err "Cannot render $slug for Ghostty and Neovim; repair $dir/colors.toml or the templates"
    DRIFT=1
  fi
done
if [ "$count" -eq 0 ]; then
  log_err "No macOS palettes in $MAC_THEMES; add colors.toml files before syncing"
  DRIFT=1
fi

[ "$DRIFT" -eq 0 ] || exit 1
log_ok "All $count Mac palettes render for Ghostty and Neovim; no Linux palettes are missing."
