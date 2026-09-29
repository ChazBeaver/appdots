# Appdots

A modular dotfiles system for managing application configurations across Linux and macOS.

Pure Bash — no dependencies, no extra tools. Symlinks configs cleanly into `$HOME` and `~/.config/`, installs OS-appropriate packages, and keeps everything verifiable with a built-in doctor.

---

## 📦 What's Inside

| Scope | Platform | What it manages |
|:------|:---------|:----------------|
| `active/shared/` | Both | Ghostty, Starship, Yazi, Zsh, Bash, Git, Herdr |
| `active/linux/` | Linux | Neovim (Linux), xdg-terminals |
| `active/macos/` | macOS | Neovim (macOS), AeroSpace, Rectangle preferences |

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

Runs four checks:

- **`doctor/default-shell.sh`** — verifies the account login shell is the installed zsh and directs shell drift to `./bootstrap.sh`
- **`doctor/symlinks.sh`** — verifies every symlink exists and points correctly
- **`doctor/packages.sh`** — compares installed packages against `packages/<os>/core.sh`, filtering out Omarchy base packages and sibling repo (hyprdots) declarations to avoid false positives
- **`doctor/herdr-integrations.sh`** — verifies each Herdr agent integration declared in `integrations/herdr.sh` is installed and still at the reviewed version (see [Herdr agent integrations](#-herdr-agent-integrations))

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

### Themes on macOS

Omarchy owns themes on Linux. On macOS the `theme` command (`bin/macos/theme.sh`)
honours the same file contract for the apps appdots themes there, Ghostty and
Neovim, so both read their theme from `~/.local/state/omarchy/current/theme/`
on either OS and need no per-OS config. Nothing is downloaded on the Mac.

Herdr follows along too, with no generated file of its own. Its own config
already sets `theme.name = "terminal"` (see `~/.config/herdr/config.toml`
`[theme]`), which makes Herdr's UI colors mirror whatever ANSI palette its
host terminal (Ghostty) is currently rendering. Herdr only re-reads that
palette on a resize or `SIGWINCH` though, so `theme set` signals the attached
Herdr client after reloading Ghostty (`notify_herdr` in `theme.sh`, found by
walking the process ancestry for the nearest `herdr` client; a no-op outside
a Herdr pane). Herdr's per-color `[theme.custom]` overrides are left alone,
since there is no per-theme file to render them into.

| Piece | Where | Notes |
|:------|:------|:------|
| Palettes | `active/macos/.config/omarchy/themes/<slug>/colors.toml` | one file per theme, copied from the theme installed on Linux |
| Templates | `active/macos/.config/omarchy/themed/*.tpl` | verbatim copies of Omarchy's `ghostty.conf.tpl` and `neovim.lua.tpl` |
| Palette resolver | `bin/macos/omarchy-theme-color.sh` | verbatim copy of Omarchy's; needs Homebrew `bash` |
| Drift check | `doctor/omarchy-vendored.sh` | on Linux, compares the copies and palettes against what is installed |

```bash
theme list                 # available themes, * marks the active one   (Neovim: <leader>tt)
theme set <slug>           # render ghostty.conf and neovim.lua, activate
theme pick                 # fzf picker (falls back to a menu); zsh alias: tt
```

To add a theme for the Mac, copy its `colors.toml` from `~/.config/omarchy/themes/<slug>/`
on Linux into a folder of the same name under the palettes directory. Only
six-digit hex colours are rendered, so a palette cannot inject anything into
the generated files. After a set, Ghostty's config is reloaded through System Events when run
inside Ghostty (macOS asks once to allow Ghostty under Accessibility);
Neovim re-applies immediately from `<leader>tt`, or on the next focus.

### system/

One-time OS mutation scripts run by `bootstrap.sh` in alphabetical order,
`system/shared/` first and then `system/<os>/`. They are never run by
`sync.sh`. The scripts are idempotent and safe to re-run, but are only
necessary when bootstrapping a machine. Bootstrap runs a temp copy of each
script, so scripts that need the repo use the exported `APP_DOTS_DIR`.

| Path | Purpose |
|:-----|:--------|
| `system/shared/20-herdr-integrations.sh` | Install missing Herdr agent integrations |
| `system/linux/10-default-shell.sh` | Set zsh as default login shell |
| `system/macos/00-default-shell.sh` | Set zsh as default login shell |
| `system/macos/10-apply-defaults.sh` | Apply macOS system defaults |
| `system/macos/20-apply-symbolic-hotkeys.sh` | Configure keyboard shortcuts |
| `system/macos/30-dock.sh` | Dock layout and behavior |
| `system/macos/40-login-items.sh` | Login items |
| `system/macos/50-browser.sh` | Default browser |

---

## 🪟 Herdr workspace layout

`herdr-workspace` (from `bin/shared/`) creates a workspace with the standard
two tabs: `chat` for the agent and `repo` for your shell.

| Key | Runs | Effect |
|:----|:-----|:-------|
| `prefix+shift+c` | `herdr-workspace new` | Prompts for a name (default: current directory), creates the workspace in the active pane's directory, names the tabs |
| `prefix+shift+l` | `herdr-workspace layout` | Adds the missing tabs to the current workspace, e.g. one herdr created for a worktree |
| `prefix+shift+w` | built-in `new_workspace` | Bare workspace with one unnamed tab |

`layout` only renames the first tab when it still has its default numeric
label and never creates a tab whose name already exists, so it is safe to run
twice. Change `FIRST_TAB` and `EXTRA_TABS` at the top of the script to alter
the layout.

---

## 🤝 Herdr agent integrations

Herdr can show each pane's agent state (working, blocked, idle) for Claude
Code, Codex, and OpenCode. That needs a small session-start hook installed
into each agent's own config directory:

```bash
herdr integration install claude
herdr integration install codex
herdr integration install opencode
```

### Why this is a bootstrap script, not a symlinked config

- Herdr **generates** the hook files and stamps each with a
  `HERDR_INTEGRATION_VERSION`. Reinstalling or upgrading overwrites them, so
  committing them here would only drift from what herdr ships.
- The install also **merges entries into files appdots does not own**
  (`~/.claude/settings.json`, `~/.codex/config.toml`,
  `~/.config/opencode/tui.jsonc`) and writes absolute `$HOME` paths into them.

So the repo persists the *intent* instead: `integrations/herdr.sh` lists the
agents and the hook version that was last read and approved.

### How it behaves

| Piece | Behaviour |
|:------|:----------|
| `integrations/herdr.sh` | Declares `agent=version` pairs. The version is the reviewed pin. |
| `system/shared/20-herdr-integrations.sh` | Run by `bootstrap.sh`. Installs integrations that are **missing** for agents on `PATH`. Never rewrites an existing hook. Skips agents not installed yet. |
| `doctor/herdr-integrations.sh` | Fails when a declared agent has no hook, when the installed version differs from the pin, or when herdr reports it has a newer hook than the one installed. |

### Why the pin matters

The hooks run with your user privileges at every agent session start, before
any permission prompt. As reviewed, they are harmless: they exit unless
launched inside a Herdr pane, then send pane id, agent name, session id, and a
state word to Herdr's local socket (`~/.config/herdr/herdr.sock`, mode 0600).
No network, no file writes beyond a temp copy of stdin. The pin exists so a
future herdr release cannot change that behaviour without you noticing.

### Upgrading a hook

When `./doctor.sh` reports a version mismatch or that herdr wants to upgrade:

1. Read the new hook. It is short. `herdr integration status` prints the path.
2. If herdr has not yet installed it: `herdr integration install <agent>`.
3. Update the pin in `integrations/herdr.sh` to the new version.
4. Re-run `./doctor.sh`.

### Installing an agent later

If Claude Code or Codex was not on the machine when `bootstrap.sh` ran, the
integration is skipped. After installing the agent, run either
`./bootstrap.sh` again or the system script directly:

```bash
./system/shared/20-herdr-integrations.sh
```

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

## 🧭 Shell Function Palette

Run `fn` to browse the appdots functions loaded on the current platform. The
palette searches function names, groups, descriptions, usage, aliases, and
former names.
Press Enter to insert a function into the prompt, `Ctrl-E` to inspect its live
definition, or `?` to toggle its help preview. It never executes a selection.

```zsh
fn                  # browse everything
fn branch           # begin with a search
fn --list git       # printable, non-interactive view
fn --source gbs     # inspect one function
gfh                 # browse every Git family with a categorized guide
gfh push            # exactly match the clean push helpers
gfh --list          # print every Git helper, ordered by section
```

Git functions use consistent families: `gb*` operates on branches, `gr*`
operates across child repositories, and other Git operations use a compact
`g*` mnemonic.

| Former name | Current name | Purpose |
|:------------|:-------------|:--------|
| `dirgcm` | `grc` | Commit and push child repositories |
| `dirgpull` | `grp` | Fast-forward child repositories |
| `dirgpullr` | `grr` | Rebase child repositories |
| `gbra` | `grs` | Audit child repository status |
| `gpush` | `gps` | Push the current branch |
| `gpull` | `gpl` | Pull the current branch |
| `stashpull` | `gsp` | Stash, pull, and restore work |
| `mm` | `gmm` | Merge `origin/main` into the current branch |
| `gbdiff` | `gdf` | List files changed across recent commits |
| `gbls` | `gbo` | List old remote branches |
| `gbcvm` | `gbv` | Compare the current branch with its base |
| `gbh` | `gfh` | Browse and search Git functions |
| `fd` | `fda` | Broad fuzzy directory search |
| `hf` | `fh` | Fuzzy history search |
| `list-functions` | `fn` | Browse appdots functions |

Aliases and former names are searchable in `fn`; the former names are
intentionally no longer callable.

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
│   ├── default-shell.sh       # Login-shell drift check
│   ├── herdr-integrations.sh  # Herdr agent hook drift check
│   ├── packages.sh            # Package drift check
│   └── symlinks.sh            # Symlink drift check
├── integrations/
│   └── herdr.sh         # Declared Herdr agent integrations + reviewed versions
├── lib/
│   ├── backup.sh        # Backup helpers
│   ├── detect.sh        # OS detection
│   ├── herdr.sh         # Herdr integration status parsing
│   ├── link.sh          # Symlink creation logic
│   └── log.sh           # Emoji logging helpers
├── packages/
│   ├── linux/core.sh    # Declared pacman / AUR packages
│   └── macos/core.sh    # Declared Homebrew formulae and casks
├── system/
│   ├── shared/          # One-time setup scripts for all platforms
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
