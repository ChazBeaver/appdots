#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf -- "$fixture"' EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

mkdir -p "$fixture/app/doctor" "$fixture/app/lib" "$fixture/app/packages/"{linux,macos} \
  "$fixture/sibling/packages/linux" "$fixture/sibling/config" "$fixture/omarchy/install" "$fixture/bin"
cp "$REPO_DIR/doctor/packages.sh" "$fixture/app/doctor/"
cp "$REPO_DIR/lib/"{log,detect}.sh "$fixture/app/lib/"
printf 'PACMAN_PKGS=(\nzsh\n)\nAUR_PKGS=(\n)\n' > "$fixture/app/packages/linux/core.sh"
printf 'BREW_FORMULAE=(\nbash\n)\nBREW_CASKS=(\nghostty\n)\n' > "$fixture/app/packages/macos/core.sh"
printf 'terraform # sibling package\n' > "$fixture/sibling/packages/linux/pacman.txt"
: > "$fixture/sibling/packages/linux/aur.txt"
printf '{"plugins":{"example":{"packages":[{"name":"plugin-tool","source":"aur"}]}}}\n' > "$fixture/sibling/config/plugin-requirements.json"
printf 'export HYPR_DOTS_DIR="%s"\n' "$fixture/sibling" > "$fixture/env"
printf 'base-tool\n' > "$fixture/omarchy/install/omarchy-base.packages"
printf 'linux-omarchy\nvulkan-radeon\n' > "$fixture/omarchy/install/omarchy-other.packages"
printf 'zsh\nterraform\nplugin-tool\nlinux-omarchy\nvulkan-radeon\nomarchy\ntransitive-dependency\n' > "$fixture/installed"
printf 'terraform\nplugin-tool\nlinux-omarchy\nvulkan-radeon\nomarchy\n' > "$fixture/leaves"
cat > "$fixture/bin/pacman" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  -Qq) cat "$APPDOTS_TEST_FIXTURE/installed" ;;
  -Qqett) cat "$APPDOTS_TEST_FIXTURE/leaves" ;;
  *) exit 2 ;;
esac
EOF
cat > "$fixture/bin/uname" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${APPDOTS_TEST_OS:-Linux}"
EOF
cat > "$fixture/bin/brew" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  'list --formula') printf 'bash\n' ;;
  leaves) : ;; # bash is installed but is required by another formula
  'list --cask') printf 'ghostty\n' ;;
  *) exit 2 ;;
esac
EOF
chmod +x "$fixture/bin/"*
export APPDOTS_TEST_FIXTURE="$fixture" APPDOTS_ENV_FILE="$fixture/env" OMARCHY_PATH="$fixture/omarchy"
export PATH="$fixture/bin:$PATH"
check() { bash "$fixture/app/doctor/packages.sh" > "$fixture/output" 2>&1; }

check || { cat "$fixture/output"; fail 'installed non-leaf/dependency or known sibling/Omarchy package reported as drift'; }
printf 'unknown-app\n' >> "$fixture/leaves"
if check; then fail 'undeclared top-level package was accepted'; fi
grep -q '+ unknown-app' "$fixture/output" || fail 'missing extra-package diagnosis'
sed '/unknown-app/d' "$fixture/leaves" > "$fixture/updated"
mv "$fixture/updated" "$fixture/leaves"
sed '/^zsh$/d' "$fixture/installed" > "$fixture/updated"
mv "$fixture/updated" "$fixture/installed"
if check; then fail 'genuinely missing declared package was accepted'; fi
grep -q -- '- zsh' "$fixture/output" || fail 'missing absent-package diagnosis'

# Older sibling checkouts still use arrays; the compatibility path must work.
mv "$fixture/sibling/packages/linux/pacman.txt" "$fixture/sibling/packages/linux/pacman.old"
mv "$fixture/sibling/packages/linux/aur.txt" "$fixture/sibling/packages/linux/aur.old"
printf 'PACMAN_PKGS=(\nterraform\n)\nAUR_PKGS=(\n)\n' > "$fixture/sibling/packages/linux/core.sh"
printf 'zsh\n' >> "$fixture/installed"
check || { cat "$fixture/output"; fail 'legacy sibling arrays were not recognized'; }

APPDOTS_TEST_OS=Darwin check || { cat "$fixture/output"; fail 'installed Homebrew non-leaf formula reported missing'; }
printf 'PASS: package presence, ownership, genuine drift, legacy manifests, and Homebrew dependencies\n'
