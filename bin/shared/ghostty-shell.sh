#!/bin/sh

if zsh_path="$(command -v zsh 2>/dev/null)" && [ -n "$zsh_path" ]; then
  SHELL="$zsh_path"
  export SHELL
  exec "$zsh_path"
fi

printf '%s\n' \
  'Ghostty could not start Zsh because it is not installed.' \
  'Install zsh with your system package manager, then reopen Ghostty.' >&2

exec /bin/sh
