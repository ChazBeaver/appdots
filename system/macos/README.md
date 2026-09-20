# system/macos/

Numbered macOS bootstrap scripts, executed in order by `bootstrap.sh`.

Move these here **as-is** from `scripts/macos/`:

- `10-apply-defaults.sh`
- `20-apply-symbolic-hotkeys.sh`
- `30-dock.sh`
- `40-login-items.sh`
- `50-browser.sh`

`00-default-shell.sh` sets zsh as the account login shell. Ghostty also uses
the appdots-managed `ghostty-shell` command, so new terminals consistently
start zsh even before the user logs out after bootstrap.

## Why numbered?

`bootstrap.sh` runs them alphabetically. Prefix numbers let you control order (defaults before dock, dock before login items, etc.) and leave room to insert new steps later (`25-finder.sh` between `20-` and `30-`).

## Imperative, not declarative

Unlike `active/`, these scripts **mutate system state**. They're run once by `bootstrap.sh`; `sync.sh` never touches them. Re-running them on an existing machine is safe (they're idempotent) but unnecessary.
