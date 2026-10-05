# Manual operations

Start here for installation and maintenance; use [SHELL.md](SHELL.md) for
every repo-defined shell function and alias. Examples assume the checkout
is `~/Projects/home/appdots`, and `nvim` is your editor (substitute another
installed editor if needed). Run only the block for your task and OS.

## Install, update, and diagnose

On a fresh Arch/Omarchy or macOS machine, clone the repository using its Git
remote URL, then:

```bash
cd ~/Projects/home/appdots
./bootstrap.sh
./doctor.sh
```

Bootstrap changes your home directory, installs packages (network and
administrative access required), applies system settings, and runs sync.
Open a new terminal afterward. It is not a documentation/test command.

For an existing installation:

```bash
cd ~/Projects/home/appdots
git status --short
git pull --ff-only           # resolve local changes/divergence before proceeding
./sync.sh
source ~/.dotfiles-env.sh
./doctor.sh
```

`sync.sh` updates links and the environment file; it does not install missing
packages or apply system settings. It replaces conflicting real files and
wrong links. Before introducing new managed paths, run `./backup.sh` and
inspect its output. These root scripts take no arguments and have no dry-run
or help mode; `./bootstrap.sh --help` would still run bootstrap.

Run the aggregate doctor or any check individually:

| Example | Checks |
| --- | --- |
| `./doctor.sh` | Every `doctor/*.sh`; success ends with `All checks passed.` |
| `bash doctor/default-shell.sh` | Account login shell. |
| `bash doctor/symlinks.sh` | Shared and OS-specific configuration links. |
| `bash doctor/packages.sh` | Declared versus installed packages. |
| `bash doctor/herdr-integrations.sh` | Installed agent hooks versus reviewed versions. |
| `bash doctor/omarchy-vendored.sh` | Resolver, templates, and Mac palettes versus Linux sources; skips on macOS. |

Treat nonzero doctor status as a finding to investigate. Package reports can
include ownership/parser drift; inspect the manifests and package-manager
output before installing or deleting anything. There is no checked-in
automated test suite in this repository.

## Back up and restore

```bash
cd ~/Projects/home/appdots
./backup.sh
```

This **moves** conflicting real HOME and `.config` items to adjacent `.bak`
paths; it skips symlinks and any item that already has a `.bak`. It does not
back up `~/.local/bin` commands or macOS `~/Library` targets. Save those
separately before replacing them. A skip is not a fresh backup.

For example, inspect a saved Zsh configuration and, if you intend to stop
using the installed version temporarily, restore it:

```bash
ls -ld ~/.zshrc ~/.zshrc.bak
diff -u ~/.zshrc.bak ~/.zshrc
# After reviewing, restore only when .zshrc is still a symlink:
test -f ~/.zshrc.bak && test -L ~/.zshrc &&
  unlink ~/.zshrc && cp -a ~/.zshrc.bak ~/.zshrc
```

`diff` exits 1 when files differ. Restoring intentionally creates link drift;
the next sync will replace it again. Copy desired changes into the repo
before syncing if they should become permanent.

## Packages and system settings

Run package installers with Bash, not `source`; they perform installations
immediately. Edit the arrays in the relevant `core.sh` to persist package
intent. Each command below is an independent operation from the repo root.

| Platform | Example | Effect/prerequisite |
| --- | --- | --- |
| Arch Linux | `bash packages/linux/core.sh` | Install declared pacman/AUR packages, bootstrapping yay if absent; requires sudo and network. |
| macOS | `bash packages/macos/core.sh` | Install/update Homebrew and declared formulae/casks; inspect individual failures even if the script completes. |
| Linux | `bash system/linux/10-default-shell.sh` | Select installed Zsh with `chsh`; may update `/etc/shells` via sudo. Log out/in afterward. |
| macOS | `bash system/macos/00-default-shell.sh` | Set the account shell to installed Zsh. |
| Both | `APP_DOTS_DIR="$PWD" bash system/shared/20-herdr-integrations.sh` | Install missing integrations for installed agents; requires Herdr. |

All other macOS system scripts have independent examples and effects in
[system/macos/README.md](system/macos/README.md). Choose those scripts to
repair a specific setting without rerunning the whole bootstrap.

For Herdr integrations, inspect status, read the hook file at the path it
prints, install the chosen agent's hook, update its reviewed version in
`integrations/herdr.sh`, then check again:

```bash
herdr integration status
herdr integration install claude    # choose the agent being installed/upgraded
herdr integration install codex
herdr integration install opencode
nvim integrations/herdr.sh
bash doctor/herdr-integrations.sh
```

`integrations/herdr.sh` is data sourced by the installer and doctor, not an
installer itself. Likewise, `lib/*.sh` are sourced internal helpers. The
`archive/` directory currently contains documentation only; its example
removal script names are proposed layout, not runnable files.

## Change a managed config or command

Edit an existing source file and run doctor; symlinked edits are visible
immediately. If you add or move a file, run backup and sync as well:

```bash
cd ~/Projects/home/appdots
nvim active/shared/.config/starship.toml
./doctor.sh
```

For a new shared command named `hello-local`, first choose a name that does
not conflict with an existing command:

```bash
mkdir -p bin/shared
cat > bin/shared/hello-local.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'Hello from appdots\n'
EOF
chmod +x bin/shared/hello-local.sh
./sync.sh
~/.local/bin/hello-local
./doctor.sh
```

Configs follow the [scope mapping](README.md#scopes). Put OS-specific changes
in `active/linux/` or `active/macos/`. Review the installed target before
adding an entire `.config/<app>` directory: normal entries link the whole
directory, while directories containing `.appdots-link-contents` link their
immediate children. Removing a source file does not automatically prune old
Appdots links; inspect and unlink the specific stale target after moving or
retiring a managed file.

## Installed commands

After sync, `~/.local/bin` must be on `PATH`. Herdr helpers require a running
Herdr session/server, `herdr`, and `jq`; pickers additionally require `fzf`.

| Source script | Installed command |
| --- | --- |
| `bin/shared/ghostty-shell.sh` | `ghostty-shell` |
| `bin/shared/herdr-fzf.sh` | `herdr-fzf` |
| `bin/shared/herdr-workspace.sh` | `herdr-workspace` |
| `bin/macos/theme.sh` | `theme` (macOS) |
| `bin/macos/omarchy-theme-color.sh` | `omarchy-theme-color` (macOS) |

```bash
herdr-workspace new                 # prompt for name; create chat/repo tabs
herdr-workspace new documentation   # same layout with an explicit name
herdr-workspace layout              # ensure tabs in this Herdr workspace
herdr workspace list                # find IDs for the next form
herdr-workspace layout WORKSPACE_ID # substitute an ID from the listing
herdr-fzf tab                       # select and focus a tab
herdr-fzf workspace                 # select and focus a workspace
herdr-fzf worktree                  # inside a Git repo; open/focus a worktree
```

`HERDR_ACTIVE_PANE_CWD` overrides the directory used for workspace creation.
`layout` uses `HERDR_ACTIVE_WORKSPACE_ID`, then `HERDR_WORKSPACE_ID`, unless
an ID is supplied. These are independent examples, not a batch to run in
sequence. Picker selection takes effect immediately; Esc cancels.

`ghostty-shell` is the configured terminal entrypoint. To reproduce it by
hand, run `~/.local/bin/ghostty-shell`; it starts a Zsh login shell (or falls
back to `/bin/sh` if Zsh is absent). Type `exit` to leave that nested shell.

### macOS themes

Requires Homebrew Bash 4+, synced palettes/templates and the resolver on
`PATH`. `pick` also requires fzf. Run on macOS, where Omarchy is not installed:

```bash
theme --help
theme list
theme current
theme set catppuccin
theme pick
```

`current` exits nonzero until a theme is selected. `set` writes generated
state under `~/.local/state/omarchy/current/`. In Ghostty, allow Accessibility
access for automatic reload, or press Cmd+Shift+, yourself. Neovim reloads
on focus or through its theme picker. Generated state is not edited/committed.

The installed `omarchy-theme-color` has a `/bin/bash` shebang; macOS's Bash
3.2 cannot run its associative arrays. Invoke the resolver explicitly using
Homebrew Bash, as `theme` itself does:

```bash
resolver_bash="$(brew --prefix bash)/bin/bash"
resolver="$(command -v omarchy-theme-color)"
"$resolver_bash" "$resolver" --help
"$resolver_bash" "$resolver" --all
"$resolver_bash" "$resolver" --raw
"$resolver_bash" "$resolver" background
"$resolver_bash" "$resolver" missing_key '#ffffff'
"$resolver_bash" "$resolver" --file ~/.config/omarchy/themes/catppuccin/colors.toml accent
```

On Linux, copy an installed palette into the Mac collection, then review:

```bash
cd ~/Projects/home/appdots
mkdir -p active/macos/.config/omarchy/themes/blue-sky
cp ~/.config/omarchy/themes/blue-sky/colors.toml active/macos/.config/omarchy/themes/blue-sky/
git diff -- active/macos/.config/omarchy/themes
bash doctor/omarchy-vendored.sh
```

After transferring the reviewed repository changes to the Mac, run sync and
`theme set blue-sky`. To refresh the resolver/templates on Linux, review the
diffs and use the exact copy commands printed by `doctor/omarchy-vendored.sh`.

## Startup updates

These scripts pull fixed checkouts and can fail on local changes. Run them
manually only when you want to fetch/rebase those repositories:

```bash
cd ~/Projects/home/appdots
bash active/shared/HOME/zsh/zsh_modules/shared/personal-repos-pull.sh
# Linux only:
bash active/shared/HOME/zsh/zsh_modules/linux/hyprdots-pull.sh
```

The first updates appdots and wikinotes; the second updates hyprdots. Neither
syncs installed files, and their final success message does not mean every
pull succeeded: read any per-repository warnings.

To disable both automatic startup pulls on Linux (only the first on macOS):

```bash
mv active/shared/HOME/zsh/zsh_modules/shared/personal-repos-pull.sh active/shared/HOME/zsh/zsh_modules/shared/personal-repos-pull.sh.bak
mv active/shared/HOME/zsh/zsh_modules/linux/hyprdots-pull.sh active/shared/HOME/zsh/zsh_modules/linux/hyprdots-pull.sh.bak
```

Restore each name by reversing the corresponding `mv`. Zsh loads only
`*.sh`, and the module directory is already linked, so the next shell picks
up the change. These renames are repository changes; review them before
making them permanent.

## Git guard and application shortcuts

The managed `.gitconfig` sets `core.hooksPath` to `~/.config/git/hooks`.
Inspect the effective setting and run the guard against staged content
without creating a commit:

```bash
git config --show-origin --get core.hooksPath
zsh ~/Projects/home/appdots/active/shared/.config/git/hooks/pre-commit
```

The guard needs Zsh, Git and grep. It scans staged added/copied/modified files
using `active/shared/.config/git/hooks/patterns/active/*.txt`, fails on a
match or missing patterns, then **executes an executable repo-local
`.git/hooks/pre-commit`**, if present. Review that local hook before invoking
the guard manually. Edit active pattern files to change the scan; archived
patterns are not loaded. A repo-local `core.hooksPath` overrides the global
setting. Wikinotes' `scripts/git-hook-dir-audit.sh` inventories these overrides.

For editor operations, see [the Neovim keymap cheatsheet](keymap_cheatsheet.md).
Start `nvim README.md`, press Space (the leader key), then the listed keys;
for example, Space f f opens file search. In Yazi (`y`), use `g h` for home
projects, `g w` for work projects, `g p` for Projects, `g d` for Downloads,
`g c` for `.config`, `g n` for work notes, `g t` for work transcripts, and
`c t` to close a tab. Destination directories must already exist.
