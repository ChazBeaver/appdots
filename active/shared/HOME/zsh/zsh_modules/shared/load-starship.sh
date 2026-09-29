# Prompt. Skipped quietly when starship is not installed (see packages/).
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi
