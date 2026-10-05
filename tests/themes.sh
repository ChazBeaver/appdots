#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf -- "$fixture"' EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

app="$fixture/app"
mac="$app/active/macos/.config/omarchy"
mkdir -p "$app/doctor" "$app/lib" "$app/bin/macos" "$mac/themes/example" "$mac/themed" \
  "$fixture/omarchy/themes/example" "$fixture/linux-themes" "$fixture/rendered"
cp "$REPO_DIR/doctor/omarchy-vendored.sh" "$app/doctor/"
cp "$REPO_DIR/lib/"{log,theme}.sh "$app/lib/"
cp "$REPO_DIR/bin/macos/omarchy-theme-color.sh" "$app/bin/macos/"
cp "$REPO_DIR/active/macos/.config/omarchy/themed/"*.tpl "$mac/themed/"
cp "$REPO_DIR/active/macos/.config/omarchy/themes/catppuccin/colors.toml" "$mac/themes/example/"
cp "$mac/themes/example/colors.toml" "$fixture/omarchy/themes/example/"
# Source content changes are deliberately not Mac palette drift.
printf '\n# independent Linux edit\n' >> "$fixture/omarchy/themes/example/colors.toml"
sed 's/#[0-9a-fA-F]\{6\}/#123456/g' "$fixture/omarchy/themes/example/colors.toml" > "$fixture/edited-palette"
mv "$fixture/edited-palette" "$fixture/omarchy/themes/example/colors.toml"
export OMARCHY_PATH="$fixture/omarchy" APPDOTS_LINUX_THEMES_DIR="$fixture/linux-themes"
check() { bash "$app/doctor/omarchy-vendored.sh" > "$fixture/output" 2>&1; }

check || { cat "$fixture/output"; fail 'different but usable palette reported as drift'; }
mkdir "$fixture/linux-themes/new-theme"
cp "$mac/themes/example/colors.toml" "$fixture/linux-themes/new-theme/"
if check; then fail 'missing Linux theme coverage was accepted'; fi
grep -q 'Missing macOS palette for Linux theme: new-theme' "$fixture/output" || fail 'missing coverage diagnosis'
mkdir "$mac/themes/new-theme"
cp "$fixture/linux-themes/new-theme/colors.toml" "$mac/themes/new-theme/"
check || fail 'adding the missing palette did not repair coverage'

printf 'background = "#112233"\n' > "$mac/themes/new-theme/colors.toml"
if check; then fail 'incomplete palette was accepted'; fi
cp "$fixture/linux-themes/new-theme/colors.toml" "$mac/themes/new-theme/"
mv "$mac/themed/neovim.lua.tpl" "$fixture/neovim.lua.tpl"
if check; then fail 'missing Neovim template was accepted'; fi
mv "$fixture/neovim.lua.tpl" "$mac/themed/neovim.lua.tpl"

# No Omarchy install on macOS: stored palettes must still be checked.
OMARCHY_PATH="$fixture/not-installed" check || fail 'standalone Mac palettes cannot be checked'
printf '\ninvalid = {{ unknown_color }}\n' >> "$mac/themed/ghostty.conf.tpl"
if OMARCHY_PATH="$fixture/not-installed" check; then fail 'unresolved template color was accepted without Omarchy'; fi

# A failed resolver must propagate instead of being hidden by process substitution.
source "$REPO_DIR/lib/log.sh"
source "$REPO_DIR/lib/theme.sh"
printf '#!/usr/bin/env bash\nexit 1\n' > "$fixture/failed-resolver"
if render_theme_templates "$mac/themes/example/colors.toml" "$mac/themed" "$fixture/rendered" "$fixture/failed-resolver" "$(find_bash4)" > "$fixture/output" 2>&1; then
  fail 'resolver failure was swallowed'
fi
printf 'PASS: palette coverage, intentional differences, renderability, Mac-only checks, and resolver failures\n'
