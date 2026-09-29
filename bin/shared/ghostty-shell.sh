#!/bin/sh
# Ghostty runs this as its `command`. Start zsh as a LOGIN shell (-l), the
# same way Terminal.app and Ghostty's own default do, so ~/.zprofile runs.
# On macOS that is where Homebrew's `brew shellenv` lives; without it nothing
# under /opt/homebrew/bin (nvim, fzf, starship, ...) is on PATH.

if zsh_path="$(command -v zsh 2>/dev/null)" && [ -n "$zsh_path" ]; then
  SHELL="$zsh_path"
  export SHELL
  exec "$zsh_path" -l
fi

printf '%s\n' \
  'Ghostty could not start Zsh because it is not installed.' \
  'Install zsh with your system package manager, then reopen Ghostty.' >&2

exec /bin/sh -l
