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
| `bash doctor/omarchy-vendored.sh` | Render every Mac palette for Ghostty/Neovim; on Linux also detect missing counterparts. Does not compare colors byte for byte. |

Treat nonzero doctor status as a finding to investigate. Missing packages
mean a declaration is unmet, not necessarily that normal desktop use is
broken. Presence checks include packages installed as dependencies; extra
package checks use the narrower top-level package set and filter Omarchy and
Hyprdots ownership. Review the declared intent before installing anything.

Run every regression fixture without installing packages or changing the desktop:

```bash
./test.sh
```

The runner discovers `tests/*.sh`, runs each script separately, continues
after failures, and returns nonzero if any suite fails. For a focused check,
run a suite directly, for example `bash tests/packages.sh`.

The package suite checks Linux ownership/presence and Homebrew non-leaf
formulae using stub package managers. The theme suite checks missing coverage,
intentional palette differences, failed rendering, and operation without Omarchy.
The Git suites exercise local branches, merges, cleanup, searchable help, and
bulk repository failures in disposable repositories and worktrees.
`bash tests/personal-repos.sh` checks installed-repository discovery, upstream
tracking, fast-forward behavior, sync/doctor script execution, and failures
without touching personal repos. It also checks cached Git status reports.
`bash tests/env.sh` checks parent-directory creation and idempotent registry
repair, including duplicate entries and literal checkout paths.
The Herdr suite uses a fake CLI to check tab setup without touching a live
session; it needs Python 3.11+ for TOML parsing.

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
| Arch Linux | `bash packages/linux/core.sh` | Install declared packages; bootstraps yay only when the AUR list is nonempty and yay is absent. Requires sudo and network. |
| macOS | `bash packages/macos/core.sh` | Install/update Homebrew and declared formulae/casks; inspect individual failures even if the script completes. |
| Linux | `bash system/linux/10-default-shell.sh` | Select installed Zsh with `chsh`; may update `/etc/shells` via sudo. Log out/in afterward. |
| macOS | `bash system/macos/00-default-shell.sh` | Set the account shell to installed Zsh. |
| Both | `APP_DOTS_DIR="$PWD" bash system/shared/20-herdr-integrations.sh` | Install missing integrations for installed agents; requires Herdr. |

### Neovim without language servers

Appdots deliberately does not install external language servers or formatters.
The `nvim-lspconfig` and `conform.nvim` integrations are also absent. Neovim
still provides normal editing, search, syntax highlighting, and the remaining
configured plugins. Use native `=` for indentation and `gq` for text wrapping;
`<leader>cf` and `:ConformInfo` are not configured.

The omitted tools are `bash-language-server`, `lua-language-server`,
`yaml-language-server`, `terraform-ls`, `pyright`, `stylua`, `shfmt`, `prettier`,
and `ruff`. They are not prerequisites for Neovim, the desktop, or running
Python, shell, Lua, or Terraform programs. Omarchy's packaged editor/runtime
remains owned by Omarchy.

On an existing machine, `:Lazy` shows installed editor plugins. After reviewing
its obsolete plugin list, `:Lazy clean` removes plugins no longer declared;
it can remove more than the two integrations above, so inspect the list first.

Prefer configured binary package repositories over the AUR. `opencode` is
listed under pacman packages because it is available in Arch's `extra` repo.
Appdots currently declares no AUR packages. Hyprdots separately owns the
AI Usage Bar and Meteobar dependencies used by its desktop widgets.

To inspect package status and dependencies without installing anything:

```bash
pacman -Q opencode                  # installed version
pacman -Qi opencode                 # installed metadata, required-by, size
pacman -Si opencode                 # available repository builds
pacman -Qm                         # packages absent from configured repositories
pacman -Qdt                        # dependency packages with no required/optional users
```

`pacman -Qm` means foreign to the current repositories, not proof of AUR
origin. `pacman -Qdt` is a review list, not an automatic removal command.
A package being unused by pacman does not rule out a shell script or plugin
using its executable. Review Omarchy's manifests and repository declarations
before removing anything.

### System settings and integrations

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
herdr-workspace worktree feature/my-change main # create a worktree with chat/repo
herdr-workspace open /path/to/worktree          # open/reuse it with chat/repo
herdr-fzf tab                       # select and focus a tab
herdr-fzf workspace                 # select and focus a workspace
herdr-fzf worktree                  # inside a Git repo; pick worktree, ensure chat/repo
```

`HERDR_ACTIVE_PANE_CWD` overrides the directory used for workspace creation.
`layout` uses `HERDR_ACTIVE_WORKSPACE_ID`, then `HERDR_WORKSPACE_ID`, unless
an ID is supplied. These are independent examples, not a batch to run in
sequence. Picker selection takes effect immediately; Esc cancels.

`worktree` and `open` require `HERDR_ENV=1` (run inside Herdr). With no branch
argument, `worktree` prompts; with no base argument, Herdr uses the current
branch's committed tip. Tab setup uses the checkout path returned by Herdr,
preserves custom tab names, and adds only missing standard tabs. Worktree
creation and opening focus the workspace after layout succeeds. Use the
Herdr shortcuts below; for branch commands see the
[local workflow](SHELL.md#a-local-branch-and-worktree-workflow).

With the configured prefix (`Ctrl+Space`), `prefix+Ctrl+T` creates a worktree
with the standard tabs, `prefix+Shift+T` removes a worktree, `prefix+T` picks
an existing worktree, and
`prefix+Shift+L` applies the layout to the current workspace. After editing the
Herdr bindings, run `herdr server reload-config` (or `prefix+Q`). Raw
`herdr worktree create/open` commands bypass the Appdots layout helper.

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
`theme set blue-sky`. Preserve working Mac palettes; Linux color edits are not
automatically adopted. Doctor reports missing counterparts and unusable
Ghostty/Neovim output, and prints a copy command for each missing palette.
For a stock theme, copy from `/usr/share/omarchy/themes/<slug>/colors.toml`
instead. Changes to the upstream resolver/templates alone do not count as
drift; update those deliberately only when needed for palette compatibility.

## Update installed repositories

Open a new Zsh terminal after updating appdots, then run:

```zsh
home-pull
# Or use the short alias: hp
```

For an existing Zsh session, load the new definition first:

```zsh
source "$APP_DOTS_DIR/active/shared/HOME/zsh/zsh_modules/shared/alias.sh"
source "$APP_DOTS_DIR/active/shared/HOME/zsh/zsh_modules/shared/git-functions.sh"
hp
```

Personal repositories live at `~/Projects/home/<repo>` on every machine;
[ADR-0001](docs/adr/0001-personal-repository-layout.md) records this convention.
`home-pull` is also available as `hp` ("home pull").
`~/.dotfiles-env.sh` is the source of installed repositories. Each installer
writes an `export NAME_DIR="$HOME/Projects/home/<repo>"` entry; aliases are ignored.
The command reloads this file on every invocation, so repositories registered
after the shell opened are included. No fixed repository names or parent
directory scan is used. Missing checkouts are reported as skipped, and
duplicate paths (including symlinks) are updated once.

Each clean checkout pulls its current branch's configured upstream with
`--ff-only --no-rebase --no-autostash`. Dirty worktrees (including untracked
files), detached HEADs, unfinished Git operations, missing upstreams, and
failed pulls count as failures. Other repositories are still processed;
the final summary gives success/failure/skip counts, and any failure makes
the command return nonzero. Check `git status` and `git branch -vv` in a
failed checkout, resolve its local work or upstream configuration, and retry.

The former automatic startup pulls have been removed on both Linux and macOS.
This command only updates Git checkouts. After reviewing incoming changes,
run the affected repository's own sync/install script and doctor as needed.

Inspect the registered repositories before updating them:

```zsh
home-status      # or ht
```

Each report uses `git status --short --branch --ahead-behind`: the `##` line
shows the branch, upstream, and available ahead/behind counts. Following lines
show staged, unstaged, and untracked files; no file lines means clean.
Counts use cached remote references, so they may lag changes on another
machine until a fetch or pull. This command does not fetch, refresh the index,
or create directories. Dirty, detached, and unborn branches can be reported
successfully. Missing checkouts are skipped; broken repositories fail without
stopping later reports. The summary counts reports, failures, and skips.

To apply configuration or check the installed machine across registered repos:

```zsh
home-sync        # or hs: run each available ./sync.sh
home-doctor      # or hd: run each available ./doctor.sh
```

These commands use the same registry discovery as `home-pull`. Each script
runs directly from its own checkout in a separate process, in registry order.
Duplicate checkout paths run once. Missing checkouts or scripts are skipped;
an existing script without execute permission is a failure. All other scripts
still run after a failure, and the final summary counts successes, failures,
and skips. Any failed script makes the command return nonzero.

Sync applies the current checkout, including uncommitted configuration edits.
Each repository controls its own sync effects: appdots relinks application
configs, hyprdots reconciles configuration/themes/plugins and may reload the
desktop, and agentdots updates installed skills and global instructions.
Doctor runs the repositories' existing read-only diagnostics and reports
drift. These helpers do not pull, invoke `sudo` themselves, or substitute
`install.sh`/`bootstrap.sh` for missing scripts. Wikinotes currently has
neither script and is skipped by both helpers; run its installer separately
when its registration needs repair. All helpers require explicit invocation.

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
