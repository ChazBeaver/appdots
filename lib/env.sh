#!/usr/bin/env bash
# Persistent appdots environment helpers. Source this file; do not execute it.

ensure_appdots_env() {
  local repo_dir="$1"
  local env_file="$HOME/.dotfiles-env.sh"
  local escaped_repo_dir
  local expected_export="export APP_DOTS_DIR=\"$repo_dir\""

  mkdir -p "$(dirname "$env_file")"
  [[ -e "$env_file" ]] || touch "$env_file"

  escaped_repo_dir="${repo_dir//\\/\\\\}"
  escaped_repo_dir="${escaped_repo_dir//|/\\|}"
  escaped_repo_dir="${escaped_repo_dir//&/\\&}"

  if grep -Fqx "$expected_export" "$env_file"; then
    :
  elif grep -q '^export APP_DOTS_DIR=' "$env_file"; then
    sed -i "s|^export APP_DOTS_DIR=.*|export APP_DOTS_DIR=\"$escaped_repo_dir\"|" "$env_file"
  else
    printf 'export APP_DOTS_DIR="%s"\n' "$repo_dir" >> "$env_file"
  fi

  if ! grep -q '^alias appdots=' "$env_file"; then
    printf '%s\n' 'alias appdots="cd \$APP_DOTS_DIR"' >> "$env_file"
  fi

  export APP_DOTS_DIR="$repo_dir"
}
