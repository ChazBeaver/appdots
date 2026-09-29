# ============================================================================
# Load Zsh Configurations
# ============================================================================

# --- Load dotfiles env (sets APP_DOTS_DIR, aliases, etc.) ---
ENV_FILE="$HOME/.dotfiles-env.sh"
[ -r "$ENV_FILE" ] && source "$ENV_FILE"

# --- macOS: put Homebrew on PATH before any module needs its tools ---
# Login shells get this from ~/.zprofile via `brew shellenv`; this covers
# non-login shells (Herdr panes, Neovim :terminal) and machines without it.
if [ "$(uname -s)" = Darwin ] && [ -z "${HOMEBREW_PREFIX:-}" ]; then
  for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [ -x "$_brew" ]; then
      eval "$("$_brew" shellenv)"
      break
    fi
  done
  unset _brew
fi

# --- Set base directory (installed location, not repo location) ---
# appdots install links this into place: ~/zsh_modules -> $APP_DOTS_DIR/active/shared/HOME/zsh/zsh_modules
BASE_DIR="$HOME/zsh_modules"

# --- Source everything inside shared/ ---
SHARED_DIR="$BASE_DIR/shared"
if [ -d "$SHARED_DIR" ]; then
  for file in "$SHARED_DIR"/*.sh; do
    [ -r "$file" ] && source "$file"
  done
fi

# --- Detect OS ---
case "$(uname -s)" in
  Darwin)  OS_NAME="macos" ;;
  Linux)   OS_NAME="linux" ;;
  *)       OS_NAME="unknown" ;;
esac

# --- Source everything inside the OS-specific folder ---
OS_DIR="$BASE_DIR/$OS_NAME"
if [ -d "$OS_DIR" ]; then
  for file in "$OS_DIR"/*.sh; do
    [ -r "$file" ] && source "$file"
  done
fi

# --- Load additional macOS-specific scripts from custom location ---
if [ -d "$HOME/Projects/work/zsh" ]; then
  # if [ "$OS_NAME" = "macos" ] && [ -d "$HOME/Projects/work/zsh" ]; then
  for file in "$HOME/Projects/work/zsh"/*.sh; do
    [ -r "$file" ] && source "$file"
  done
fi

LOCAL_ENV="$HOME/.local/bin/env"
[ -r "$LOCAL_ENV" ] && source "$LOCAL_ENV"
