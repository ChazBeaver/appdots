#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
# appdots/bin/macos/theme.sh
# macOS counterpart of `omarchy theme` for the two apps appdots themes on a
# Mac: Ghostty and Neovim. It honours the same file contract Omarchy uses on
# Linux, so the shared Ghostty config and the Neovim theme modules work
# unchanged on both:
#
#   ~/.config/omarchy/themes/<slug>/colors.toml   palette (versioned in appdots)
#   ~/.config/omarchy/themed/*.tpl                templates (vendored from Omarchy)
#   ~/.local/state/omarchy/current/theme/         generated ghostty.conf, neovim.lua
#   ~/.local/state/omarchy/current/theme.name     active slug
#
# Themes are plain palette files under active/macos/.config/omarchy/themes/;
# nothing is downloaded. Palette resolution is Omarchy's own
# omarchy-theme-color, vendored verbatim in bin/macos/; on Linux
# doctor/omarchy-vendored.sh checks palette coverage and renderability,
# allowing intentional differences from Linux. Only six-digit hex colours
# are rendered, so palette values cannot inject code into generated files.
#
# Usage:
#   theme list              themes available (* marks the active one)
#   theme current           print the active slug
#   theme set <slug>        render and activate a theme
#   theme pick              choose with fzf and set (zsh alias: tt)
#
# After a set, Ghostty's config is reloaded by sending its reload keystroke
# through System Events when run inside Ghostty. macOS asks once to allow
# Ghostty under Privacy & Security > Accessibility; until then the command
# prints the manual shortcut instead.
#
# Requires bash 4+ (brew install bash) for the vendored resolver; this script
# finds it explicitly instead of trusting PATH, since macOS's own /bin/bash
# is 3.2 and is still findable as a bare `bash` on a stock shell.
#
# Herdr follows along automatically (its config already sets theme.name =
# "terminal"); see notify_herdr below for the one nudge it needs.

# Follow the installed ~/.local/bin/theme symlink to the repository library.
theme_script="${BASH_SOURCE[0]}"
while [ -L "$theme_script" ]; do
  theme_dir="$(cd -- "$(dirname -- "$theme_script")" && pwd)"
  theme_script="$(readlink "$theme_script")"
  case "$theme_script" in /*) ;; *) theme_script="$theme_dir/$theme_script" ;; esac
done
theme_repo="$(cd -- "$(dirname -- "$theme_script")/../.." && pwd)"
source "$theme_repo/lib/log.sh"
source "$theme_repo/lib/theme.sh"

[ -n "${HOME:-}" ] || { printf '❌ HOME is not set\n' >&2; exit 1; }
THEMES_DIR="$HOME/.config/omarchy/themes"
TEMPLATES_DIR="$HOME/.config/omarchy/themed"
STATE_DIR="$HOME/.local/state/omarchy/current"
CURRENT_DIR="$STATE_DIR/theme"
NEXT_DIR="$STATE_DIR/next-theme"

die() { printf '❌ %s\n' "$*" >&2; exit 1; }
info() { printf 'ℹ️  %s\n' "$*"; }
ok() { printf '✅ %s\n' "$*"; }

# THEME_ALLOW_WITH_OMARCHY=1 lets the test harness run this beside a real
# Omarchy install with HOME pointed at a scratch directory.
if [ -z "${THEME_ALLOW_WITH_OMARCHY:-}" ] && command -v omarchy >/dev/null 2>&1; then
  die "Omarchy owns themes on this machine; use: omarchy theme set <name>"
fi

resolver="$(command -v omarchy-theme-color || true)"
[ -n "$resolver" ] || die "omarchy-theme-color not on PATH; run appdots sync.sh"

# The vendored resolver uses declare -A (bash 4+). macOS ships bash 3.2 as
# /bin/bash for license reasons, and it is still the first `bash` on PATH on
# a stock shell, so a bare `bash "$resolver"` silently runs the wrong one and
# fails deep inside the script. Find an actual bash 4+ instead of trusting
# PATH: check PATH first (works once Homebrew's shellenv puts its bash
# ahead), then Homebrew's two install prefixes directly.
resolver_bash="$(find_bash4)" || die "Need bash 4+ for the theme colors; run: brew install bash"

theme_slugs() {
  [ -d "$THEMES_DIR" ] || return 0
  local dir
  for dir in "$THEMES_DIR"/*/; do
    [ -f "$dir/colors.toml" ] || continue
    basename "$dir"
  done
}

current_slug() {
  [ -f "$STATE_DIR/theme.name" ] && cat "$STATE_DIR/theme.name" || true
}

cmd_list() {
  local cur slug
  cur="$(current_slug)"
  while IFS= read -r slug; do
    [ -n "$slug" ] || continue
    if [ "$slug" = "$cur" ]; then printf '* %s\n' "$slug"; else printf '  %s\n' "$slug"; fi
  done < <(theme_slugs)
}

cmd_current() {
  local cur
  cur="$(current_slug)"
  [ -n "$cur" ] || die "No theme set yet; run: theme pick"
  printf '%s\n' "$cur"
}

# Herdr's own "terminal" theme (see ~/.config/herdr/config.toml [theme]
# name = "terminal") already follows the host terminal's live ANSI palette,
# which is exactly what render_theme_templates just wrote into Ghostty's config.
# Herdr only re-reads those colors on a resize or SIGWINCH though (its own
# docs: https://herdr.dev, "Theme" section), so nudge the attached client
# after every set. Walks the process ancestry to find it, since the socket
# API describes panes, not the client's own PID, and only the nearest
# ancestor named `herdr` is the client actually rendering this pane.
notify_herdr() {
  [ "${HERDR_ENV:-}" = 1 ] || return 0
  local pid="$$" ppid comm depth=0
  while [ "$depth" -lt 12 ]; do
    ppid="$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')"
    [ -n "$ppid" ] && [ "$ppid" != 0 ] || return 0
    comm="$(ps -o comm= -p "$ppid" 2>/dev/null)"
    if [ "$comm" = herdr ]; then
      kill -WINCH "$ppid" 2>/dev/null && info "Herdr: refreshed UI colors"
      return 0
    fi
    pid="$ppid"
    depth=$((depth + 1))
  done
}

# Ghostty does not watch its config, so trigger its reload_config action
# (Cmd+Shift+, on macOS) in the frontmost app, but only when this shell is
# running inside Ghostty so the keystroke cannot land elsewhere.
reload_ghostty() {
  [ "$(uname -s)" = Darwin ] || return 0
  if [ "${TERM_PROGRAM:-}" != ghostty ] && [ -z "${GHOSTTY_RESOURCES_DIR:-}" ]; then
    info "Ghostty: reload its config (Cmd+Shift+,) in each window"
    return 0
  fi
  if osascript -e 'tell application "System Events" to keystroke "," using {command down, shift down}' >/dev/null 2>&1; then
    ok "Ghostty config reloaded"
  else
    info "Ghostty: reload with Cmd+Shift+, (to automate, allow Ghostty under System Settings > Privacy & Security > Accessibility)"
  fi
}

cmd_set() {
  local slug="${1:-}" colors
  [ -n "$slug" ] || die "Usage: theme set <slug>"
  case "$slug" in */*|.*) die "Invalid theme name: $slug" ;; esac
  colors="$THEMES_DIR/$slug/colors.toml"
  [ -f "$colors" ] || die "No theme '$slug' under $THEMES_DIR (see: theme list)"
  [ -L "$colors" ] && die "Refusing $slug: colors.toml is a symlink"

  rm -rf "$NEXT_DIR"
  mkdir -p "$NEXT_DIR"
  cp "$colors" "$NEXT_DIR/colors.toml"
  render_theme_templates "$NEXT_DIR/colors.toml" "$TEMPLATES_DIR" "$NEXT_DIR" "$resolver" "$resolver_bash"

  # Neovim watches the mtime of neovim.lua and re-applies on the next focus;
  # Ghostty reads ghostty.conf on config reload.
  rm -rf "$CURRENT_DIR"
  mv "$NEXT_DIR" "$CURRENT_DIR"
  printf '%s\n' "$slug" >"$STATE_DIR/theme.name"

  ok "Theme set to $slug"
  reload_ghostty
  notify_herdr
}

cmd_pick() {
  local slugs slug
  slugs="$(theme_slugs)"
  [ -n "$slugs" ] || die "No themes under $THEMES_DIR; run appdots sync.sh"
  command -v fzf >/dev/null 2>&1 || die "fzf not found; run: brew install fzf (or open a new terminal if just installed)"
  slug="$(printf '%s\n' "$slugs" | fzf --prompt='Theme > ' --height=40% --reverse)" || true
  [ -n "${slug:-}" ] || exit 0
  cmd_set "$slug"
}

case "${1:-}" in
  list) cmd_list ;;
  current) cmd_current ;;
  set) shift; cmd_set "${1:-}" ;;
  pick) cmd_pick ;;
  ''|-h|--help) sed -n '/^# Usage:/,/^#$/p' "$0" | sed 's/^# \{0,1\}//' ;;
  *) die "Unknown command: $1 (try: theme --help)" ;;
esac
