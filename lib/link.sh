#!/usr/bin/env bash
# appdots/lib/link.sh
# Symlink creation logic. Source this; do not execute.
# Depends on: lib/log.sh, lib/detect.sh

# link_item SOURCE TARGET
# Create a symlink SOURCE -> TARGET. Replaces wrong symlinks or real files
# in-place. Refuses to touch protected macOS Library roots.
link_item() {
  local source="$1"
  local target="$2"

  # Safety: never replace macOS Library roots themselves
  # (file-level items inside Preferences / Application Support are allowed)
  case "$target" in
    "$HOME/Library" | "$HOME/Library/Preferences" | "$HOME/Library/Application Support")
      log_err "Refusing to modify protected path: $target"
      return 1
      ;;
  esac

  # Already linked correctly? No-op.
  if [ -L "$target" ] && [ "$(readlink "$target" 2>/dev/null || true)" = "$source" ]; then
    log_ok "Already linked: $target"
    return 0
  fi

  # Exists but wrong? Remove and relink.
  if [ -L "$target" ]; then
    rm -f "$target"
    log_replace "Replacing symlink: $target"
  elif [ -e "$target" ]; then
    rm -rf "$target"
    log_clean "Removed existing file/dir: $target"
  fi

  mkdir -p "$(dirname "$target")"
  ln -s "$source" "$target"
  log_link "$source → $target"
}

# install_home_scope HOME_PATH
# Bucket rules:
#   - dotfile/dotdir at top level          -> link to $HOME/<name>
#   - non-dot dir (container) at top level -> link its immediate CHILDREN to $HOME/<child>
install_home_scope() {
  local home_path="$1"
  [ -d "$home_path" ] || return 0

  log_home "Installing HOME from: $home_path"

  find "$home_path" -mindepth 1 -maxdepth 1 | while read -r entry; do
    local base
    base="$(basename "$entry")"

    if [ -d "$entry" ] && [[ "$base" != .* ]]; then
      find "$entry" -mindepth 1 -maxdepth 1 | while read -r item; do
        local name
        name="$(basename "$item")"
        link_item "$item" "$HOME/$name"
      done
    else
      link_item "$entry" "$HOME/$base"
    fi
  done
}

# install_config_scope CONFIG_PATH
# 1:1 mirror: .config/<entry> -> ~/.config/<entry>
install_config_scope() {
  local config_path="$1"
  [ -d "$config_path" ] || return 0

  log_config "Installing .config from: $config_path"
  find "$config_path" -mindepth 1 -maxdepth 1 | while read -r item; do
    local name
    name="$(basename "$item")"
    if [ -d "$item" ] && [ -f "$item/.appdots-link-contents" ]; then
      mkdir -p "$HOME/.config/$name"
      find "$item" -mindepth 1 -maxdepth 1 ! -name .appdots-link-contents | while read -r child; do
        link_item "$child" "$HOME/.config/$name/$(basename "$child")"
      done
    else
      link_item "$item" "$HOME/.config/$name"
    fi
  done
}

# install_macos_library_scope LIB_PATH
# macOS only. Deep walk: create matching dirs, symlink files.
install_macos_library_scope() {
  local lib_path="$1"
  [ -d "$lib_path" ] || return 0
  [ "$(detect_os)" = "macos" ] || return 0

  log_library "Installing Library from: $lib_path"
  find "$lib_path" -mindepth 1 | while read -r item; do
    local rel target
    rel="${item#$lib_path/}"
    target="$HOME/Library/$rel"

    if [ -d "$item" ]; then
      mkdir -p "$target"
      continue
    fi
    link_item "$item" "$target"
  done
}

# install_bin_scope BIN_DIR OS
# Symlinks bin/shared/* -> ~/.local/bin/<n>   (cross-platform)
#          bin/<OS>/*   -> ~/.local/bin/<n>   (OS-specific)
# Strips trailing .sh from the link name so scripts run as bare commands.
install_bin_scope() {
  local bin_dir="$1"
  local os="$2"
  [ -d "$bin_dir" ] || return 0

  mkdir -p "$HOME/.local/bin"
  log_sync "Syncing bin into ~/.local/bin"

  local -a dirs=()

  # Cross-platform scripts under bin/shared/
  if [ -d "$bin_dir/shared" ]; then
    while IFS= read -r f; do
      dirs+=("$f")
    done < <(find "$bin_dir/shared" -mindepth 1 -maxdepth 1 -type f | sort)
  fi

  # OS-specific scripts under bin/<os>/
  if [ -d "$bin_dir/$os" ]; then
    while IFS= read -r f; do
      dirs+=("$f")
    done < <(find "$bin_dir/$os" -mindepth 1 -maxdepth 1 -type f | sort)
  fi

  for src in "${dirs[@]}"; do
    local name
    name="$(basename "$src")"
    name="${name%.sh}"
    chmod +x "$src"
    link_item "$src" "$HOME/.local/bin/$name"
  done
}

# install_scope SCOPE_DIR
# Dispatch HOME / .config / library scopes inside a single active/<layer>/ dir.
install_scope() {
  local scope_dir="$1"
  [ -d "$scope_dir" ] || return 0

  log_step "Processing scope: $scope_dir"
  install_home_scope          "$scope_dir/HOME"
  install_config_scope        "$scope_dir/.config"
  install_macos_library_scope "$scope_dir/library"
}
