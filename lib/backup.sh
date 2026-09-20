#!/usr/bin/env bash
# hyprdots/lib/backup.sh
# Backup helpers. Source this; do not execute.
# Depends on: lib/log.sh

backup_item() {
  local target="$1"
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    if [ -e "$target.bak" ] || [ -L "$target.bak" ]; then
      log_warn "Backup already exists: $target.bak (skipped)"
    else
      mv "$target" "$target.bak"
      log_backup "$target → $target.bak"
    fi
  fi
}

backup_home_scope() {
  local layer_dir="$1"
  local home_path="$layer_dir/HOME"
  [ -d "$home_path" ] || return 0

  log_home "Scanning HOME: $home_path"
  find "$home_path" -mindepth 1 -maxdepth 1 | while read -r bucket; do
    [ -d "$bucket" ] || continue
    find "$bucket" -mindepth 1 -maxdepth 1 | while read -r item; do
      backup_item "$HOME/$(basename "$item")"
    done
  done
}

backup_config_scope() {
  local layer_dir="$1"
  local cfg="$layer_dir/.config"
  [ -d "$cfg" ] || return 0

  log_config "Scanning .config: $cfg"
  find "$cfg" -mindepth 1 -maxdepth 1 | while read -r entry; do
    local name
    name="$(basename "$entry")"
    if [ -d "$entry" ] && [ -f "$entry/.appdots-link-contents" ]; then
      find "$entry" -mindepth 1 -maxdepth 1 ! -name .appdots-link-contents | while read -r child; do
        backup_item "$HOME/.config/$name/$(basename "$child")"
      done
    else
      backup_item "$HOME/.config/$name"
    fi
  done
}

backup_layer() {
  local layer_dir="$1"
  [ -d "$layer_dir" ] || return 0
  log_step "Scanning: $layer_dir"
  backup_home_scope   "$layer_dir"
  backup_config_scope "$layer_dir"
}
