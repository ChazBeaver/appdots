# Appdots agent instructions

Appdots is the application-config layer for Linux and macOS: shell, Ghostty,
Neovim, Git, Yazi, Starship, Herdr, and a declared package list, all
symlinked into `$HOME` by `sync.sh`. `README.md` explains the layout and
scopes; this file covers only what an agent must do differently here.

## Boundaries

- Only files under `active/<scope>/` and `bin/<scope>/` are owned here, and
  each is mirrored to a fixed place in `$HOME` (see README "Scopes"). Do not
  add Hyprland or Omarchy config (hyprdots owns it) or agent skills and
  instructions (agentdots owns them).
- Never commit secrets, credentials, browser or password-manager state, or
  shell history. `.gitignore` already lists the known ones; extend it before
  adding a new config directory.
- Do not commit or push unless asked. Leave changes in the working tree and
  offer a Conventional Commit message.

## Verify every change

```bash
./sync.sh       # relink after adding, moving, or renaming a managed file
./doctor.sh     # symlinks, packages, login shell; must end with "All checks passed"
```

`bootstrap.sh` is for a fresh machine only; `system/` scripts run from it
and never from sync. Do not run bootstrap to test a change.

## Where a change goes

- Cross-platform config goes in `active/shared/`; OS-only config in
  `active/linux/` or `active/macos/`. A file in an OS scope overrides the
  shared one, so never keep two copies when one scope-specific override
  will do.
- Shell behavior lives in `active/shared/HOME/zsh/zsh_modules/<scope>/`.
  A public function is registered with `_ad_register` immediately after its
  definition so `fn` and `gfh` can find it; a renamed function keeps its
  former name in the registry's legacy field rather than as a callable alias.
- Scripts in `bin/<scope>/` are linked to `~/.local/bin/` with `.sh`
  stripped, so name them for the command they become.
- Packages go in `packages/<os>/core.sh` by name only. Do not duplicate a
  package that Omarchy's base manifest or hyprdots already declares; doctor
  filters those and would otherwise report false drift.

## Code conventions

- Bash with `set -euo pipefail` and `IFS=$'\n\t'`; log through `lib/log.sh`
  helpers rather than bare `echo`. `lib/` files are sourced, never executed.
- Every `doctor/*.sh` is a standalone read-only check that exits non-zero
  on drift and names the command that fixes it.
- Prefer zsh-portable constructs in shell modules; the managed Bash config
  exists only to hand off to zsh.
