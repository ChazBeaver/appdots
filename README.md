# Appdots

A modular dotfiles system for managing application configurations across Linux and macOS.

Pure Bash — no dependencies, no extra tools. Symlinks configs cleanly into `$HOME` and `~/.config/`, installs OS-appropriate packages, and keeps everything verifiable with a built-in doctor.

---

## 📦 What's Inside

| Scope | Platform | What it manages |
|:------|:---------|:----------------|
| `active/shared/` | Both | Ghostty, Starship, Yazi, Zsh, Bash, Git, Herdr |
| `active/linux/` | Linux | Neovim (Linux), xdg-terminals |
| `active/macos/` | macOS | Neovim (macOS), Rectangle preferences |

---

## 🚀 Quick Start

### Fresh machine (first time)

```bash
git clone <repo-url> ~/appdots
cd ~/appdots
./bootstrap.sh
```

`bootstrap.sh` runs in order:
1. **Backup** — renames any conflicting real files to `.bak`
2. **Packages** — installs declared packages via `pacman`/`yay` (Linux) or `brew` (macOS)
3. **System tweaks** — applies OS-level settings from `system/<os>/`
4. **Sync** — symlinks all configs into place

### After a git pull

```bash
./sync.sh
```

Idempotent — safe to run as many times as you like.

---

## 🗂 Backup Before Sync

```bash
./backup.sh
```

Renames any real (non-symlink) files that sync would replace, appending `.bak`. Run this manually before your first sync on a machine with existing configs.

---

## 🔍 Diagnostics

```bash
./doctor.sh
```

Runs three checks:

- **`doctor/default-shell.sh`** — verifies the account login shell is the installed zsh and directs shell drift to `./bootstrap.sh`
- **`doctor/symlinks.sh`** — verifies every symlink exists and points correctly
- **`doctor/packages.sh`** — compares installed packages against `packages/<os>/core.sh`, filtering out Omarchy base packages and sibling repo (hyprdots) declarations to avoid false positives

Exit code is non-zero if drift is detected. Run `./sync.sh` to fix symlink
drift; run `./bootstrap.sh` to fix login-shell drift.

---

## 🔧 How It Works

### Scopes

Each `active/<scope>/` directory mirrors into your home using three sub-structures:

| Sub-path | What happens |
|:---------|:-------------|
| `active/<scope>/HOME/<bucket>/<file>` | Symlinked to `~/<file>` |
| `active/<scope>/.config/<entry>` | Symlinked to `~/.config/<entry>` |
| `active/<scope>/library/<path>` | Symlinked to `~/Library/<path>` (macOS only) |

`sync.sh` processes `shared/` first, then the OS-specific scope. Later entries win on conflict.

Ghostty explicitly launches the appdots-managed `ghostty-shell` helper. As a
defensive fallback, the managed interactive Bash configuration immediately
hands off to zsh if a terminal starts Bash before its launch configuration has
converged. An already-running shell process must be restarted once; all later
interactive sessions enter zsh automatically.

### bin/

Scripts in `bin/` are symlinked into `~/.local/bin/` with `.sh` stripped from the name, making them available as bare commands:

| Path | Symlinked as |
|:-----|:------------|
| `bin/shared/<script>.sh` | `~/.local/bin/<script>` |
| `bin/linux/<script>.sh` | `~/.local/bin/<script>` (Linux only) |
| `bin/macos/<script>.sh` | `~/.local/bin/<script>` (macOS only) |

### system/

One-time OS mutation scripts run by `bootstrap.sh` in alphabetical order.
They are never run by `sync.sh`. The scripts are idempotent and safe to
re-run, but are only necessary when bootstrapping a machine.

| Path | Purpose |
|:-----|:--------|
| `system/linux/10-default-shell.sh` | Set zsh as default login shell |
| `system/macos/00-default-shell.sh` | Set zsh as default login shell |
| `system/macos/10-apply-defaults.sh` | Apply macOS system defaults |
| `system/macos/20-apply-symbolic-hotkeys.sh` | Configure keyboard shortcuts |
| `system/macos/30-dock.sh` | Dock layout and behavior |
| `system/macos/40-login-items.sh` | Login items |
| `system/macos/50-browser.sh` | Default browser |

---

## 🔧 Environment

`bootstrap.sh` creates or repairs `APP_DOTS_DIR` and the `appdots` alias in
`~/.dotfiles-env.sh` before any bootstrap stage runs. `sync.sh` converges the
same file on later runs. This file is shared with hyprdots so both repos can
filter each other's package declarations from drift reports.

Make sure it's sourced in your shell rc:

```bash
# ~/.zshrc or ~/.bashrc
[ -f ~/.dotfiles-env.sh ] && source ~/.dotfiles-env.sh
```

The `appdots` alias drops you into the repo directory from anywhere.

---

## 🔄 Auto Git Pull

Zsh loads `active/shared/HOME/zsh/zsh_modules/shared/personal-repos-pull.sh` on every new terminal session, which runs `git pull --rebase` on both appdots and hyprdots automatically.

To disable, rename that file to `.sh.bak` and re-run `./sync.sh`.

---

## 📁 Repo Layout

```
appdots/
├── active/
│   ├── shared/          # Configs for all platforms
│   ├── linux/           # Linux-specific configs
│   └── macos/           # macOS-specific configs
├── bin/
│   ├── shared/          # Cross-platform scripts → ~/.local/bin/
│   ├── linux/           # Linux scripts          → ~/.local/bin/
│   └── macos/           # macOS scripts          → ~/.local/bin/
├── doctor/
│   ├── default-shell.sh  # Login-shell drift check
│   ├── packages.sh      # Package drift check
│   └── symlinks.sh      # Symlink drift check
├── lib/
│   ├── backup.sh        # Backup helpers
│   ├── detect.sh        # OS detection
│   ├── link.sh          # Symlink creation logic
│   └── log.sh           # Emoji logging helpers
├── packages/
│   ├── linux/core.sh    # Declared pacman / AUR packages
│   └── macos/core.sh    # Declared Homebrew formulae and casks
├── system/
│   ├── linux/           # One-time Linux setup scripts
│   └── macos/           # One-time macOS setup scripts
├── backup.sh            # Back up before sync
├── bootstrap.sh         # Cold-boot: backup + packages + system + sync
├── doctor.sh            # Run all diagnostics
└── sync.sh              # Symlink sync (run after git pull)
```

---

## 🔄 Relationship with Hyprdots

`appdots` and `hyprdots` are sibling repos. Both write their install path to `~/.dotfiles-env.sh` so each repo's `doctor/packages.sh` can filter out the other's declared packages from drift reports, preventing false positives.

Both repos share the same `lib/` architecture and shell conventions.

---

## 📜 License

MIT License
