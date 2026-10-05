# Shell command reference

These are Appdots' public Zsh functions and aliases. Install with `./sync.sh`
and open a new Zsh terminal. Most interactive pickers require `fzf`; preview
commands may also use `bat` and `tree`. The startup modules source definitions
and settings; do not execute `functions.sh`, `alias.sh`, registry, completion,
history, environment, plugin-loader, or prompt modules with Bash.

To inspect just the shared functions without triggering startup pulls:

```zsh
zsh -f
source ~/Projects/home/appdots/active/shared/HOME/zsh/zsh_modules/shared/00-function-registry.sh
source ~/Projects/home/appdots/active/shared/HOME/zsh/zsh_modules/shared/functions.sh
source ~/Projects/home/appdots/active/shared/HOME/zsh/zsh_modules/shared/git-functions.sh
source ~/Projects/home/appdots/active/shared/HOME/zsh/zsh_modules/shared/fzf.sh
fn --list
```

Type `exit` to leave that inspection shell. Normal startup also loads the
current OS's modules. Repository aliases (`appdots`, `hyprdots`, `agentdots`,
`wikinotes`, `w`) come from each repo's installer and `~/.dotfiles-env.sh`.

## Discover and inspect

```zsh
fn                         # pick a command to insert into the prompt
fn branch                  # start with a search term
fn --list                  # printable list; no picker
fn --list --group git      # all Git families
fn --source gbs            # show the live definition
fn --help                  # full palette options
gfh                        # Git-specific guide/picker
gfh push                   # search Git help
gfh --list                 # printable Git guide
```

In `fn`, Enter inserts a command; Ctrl-E shows its definition; `?` toggles
help. Inspect the resulting prompt and add arguments before executing it.
Former names in the README are searchable metadata, not callable aliases.

## Navigation, files, and applications

Each row is an independent invocation. Missing paths/tools must be created
or installed first; `mkcd` and `notes` create their own target directories.

| Example | Result/prerequisite |
| --- | --- |
| `home` | Pick an immediate child of `~/Projects/home` and cd into it. |
| `work` | Linux: pick an immediate child of `~/Projects/work`. |
| `reporoot` or `rr` | From below `~/Projects/home/<repo>` or `~/Projects/work/<repo>`, cd to that top-level project. |
| `mkcd ~/Projects/home/scratch-example` | Create the directory and cd into it. |
| `fda ~/Projects` | Pick any directory under the supplied root (default: home). |
| `FD_MAX_RESULTS=5000 fda --all` | Search from `/`, excluding runtime trees and limiting results. |
| `fcd ~/Projects` | Pick a non-hidden directory under a root (default: current directory). |
| `fe .` | Pick a file and open it in Neovim. |
| `fh` | Pick from this shell's history and insert the command into the prompt. |
| `y ~/Downloads` | Open Yazi, then adopt its final directory when it exits. |
| `notes` | Open Yazi in `~/Documents/notes` on Linux or `~/Projects/work/notes` on macOS; this is separate from Wikinotes. |
| `cx` | Launch the installed Codex CLI in `~/.codex`, then return; it takes no forwarded arguments. |
| `edit-zshrc` | Edit `~/.zshrc` via Vim (normally aliased to Neovim). |
| `printcolors` | Display terminal colors 0–255. |
| `cava` | Linux: launch Cava with `~/.config/omarchy/current/theme/cava_theme`; requires that file and the binary. If the legacy path is absent, use `command cava -p ~/.local/state/omarchy/current/theme/cava_theme` with a theme providing it. |
| `cam` or `cam overlay` | Linux: call external `webcam-launch` in overlay mode; requires that helper, which this repo does not ship. |
| `edit-ghostty` | macOS: edit `~/Library/Application Support/com.mitchellh.ghostty/config`; this is a legacy path, while the managed config is `~/.config/ghostty/config`. Use `nvim ~/.config/ghostty/config` for the managed file. |

If an fzf preview is hidden, press `?`. Appdots' generic Ctrl-Y clipboard
binding requires macOS `pbcopy`; Ctrl-E launches Vim and Ctrl-V launches
`code`, so those bindings require their respective tools.

## Git functions

Run single-repo commands inside a Git checkout. Remote operations require a
configured `origin` and working authentication. Examples using `main` assume
that branch exists; substitute the real base branch otherwise.

| Example | Effect |
| --- | --- |
| `grs ~/Projects/home` | Print clean/changed state for child repositories. |
| `grp ~/Projects/home` | Fetch/prune and fast-forward each child repository; reports failures. |
| `grr ~/Projects/home` | Fetch/prune and rebase with autostash in each child repository. |
| `grc ~/Projects/home 'chore: clarify manual usage'` | **Stage all changes, commit, and push in every child repo**, using managed `git aa`, `git com`, and `gps`. Use only when all those changes are intended. |
| `gps` | Push the current branch to origin and set upstream tracking. |
| `gpl` | Pull `origin/<current-branch>` using Git's configured merge/rebase policy. |
| `gsp` | Stash tracked changes, pull, then restore only the stash it created. Untracked files are not stashed. |
| `gmm` | Fetch origin and merge `origin/main` into the current branch. |
| `gdf` or `gdf 3` | List files changed over one or three commits; requires enough history. |
| `gbl` or `gbl ~/Projects/home/appdots` | List local and origin branches without fetching. |
| `gbs` or `gbs ~/Projects/home/appdots` | Pick a branch and insert a switch command; it runs only when you accept the prompt. |
| `gbu main` | Check out main, then pull origin/main. |
| `gbo` | Fetch/prune and list remote branches with commits older than 30 days, excluding remote main/HEAD. |
| `gbv main` | Show this branch's changed files since the merge base with origin/main (or local main). |
| `gbp` | Fetch/prune remote refs and report local branches whose upstream is gone. |
| `gbr main` | Fetch/prune and report active, merged, and upstream-gone local branches. |
| `gbd main` | Fetch/prune; pick deletion candidates with Tab/Enter and insert a deletion command for review. |

The `gr*` directory argument defaults to the current directory; they inspect
immediate children, not arbitrary descendants. A summary can report failures
even if the function's final exit status is zero. `gbd` uses `git branch -D`
for upstream-gone selections: accepting that prompt can discard unmerged
branches. `gbs` remote selections create a tracking branch; choose the local
entry when that branch already exists.

For pull/merge failures, inspect `git status` in the affected repo. Resolve
conflicted files and use `git rebase --continue` or `git merge --continue`
as appropriate, or abort that operation with `git rebase --abort` / `git
merge --abort`. After failed `gsp`, inspect `git stash list` and `git stash
show -p 'stash@{0}'` before applying a saved stash yourself.

## Shell aliases

| Examples | Expansion / effect |
| --- | --- |
| `cl`; `h sync` | Clear screen; search shell history for `sync`. |
| `..`; `...`; `....`; `.....` | Cd up 1, 2, 3, or 4 levels. |
| `bd`; `root` | Cd to previous directory; cd home. |
| `doc`; `pro`; `pic`; `dow`; `bak` | Cd to Documents, Projects, Pictures, Downloads, or Backups under home. |
| `chx ./example.sh`; `chax ./example.sh` | Add execute permission for the default classes, or explicitly all users. |
| `v`; `vim README.md`; `vimdiff README.md MANUAL.md` | Neovim on the current directory, a file, or two files in diff mode. |
| `ls`; `la`; `tree .` | Eza listings/tree (requires `eza`); OS modules override the shared tree alias. |
| `k get pods`; `hr` | `kubectl get pods` (requires configured cluster access); start Herdr. |
| `matrix` | Linux: run `cmatrix -b -s -u 6`; exit with a key. |
| `here`; `tt` | macOS: open current directory in Finder; run `theme pick`. |

The numeric aliases apply permissions **recursively**. These examples target
only a disposable file; do not use them on a repo or your home directory:

```zsh
permission_example=$(mktemp)
000 "$permission_example"   # no permissions
644 "$permission_example"   # owner read/write; everyone else read
666 "$permission_example"   # everyone read/write
755 "$permission_example"   # owner write; everyone read/execute
777 "$permission_example"   # everyone read/write/execute
rm "$permission_example"
```

## Git aliases

These are subcommands (`git ss`, not `ss`). Inspect the installed list with
`git alias`. Commit examples assume you have intentionally staged changes.

| Examples | Meaning |
| --- | --- |
| `git alias`; `git econfig` | List aliases; edit global Git configuration. |
| `git s`; `git ss`; `git ssb` | Status; short status; short status with branch. |
| `git a README.md`; `git aa` | Stage one file; stage all changes. |
| `git co`; `git com 'chore: explain setup'`; `git coma 'chore: explain setup'` | Commit via editor; commit staged files with message; stage tracked changes and commit with message. |
| `git unstage` | Unstage all paths under the current directory, preserving working files. |
| `git uncommit` | Soft-reset one commit, keeping its changes staged; only use when intentionally rewriting local history. |
| `git cleandir` | Discard unstaged tracked-file changes under the current directory. |
| `git rb main`; `git rbi HEAD~3` | Rebase onto main; interactively rewrite the last three commits. |
| `git rba`; `git rbc`; `git rbs` | Abort, continue, or skip the current rebase step. Skipping drops that commit's changes. |
| `git pr` | Pull with rebase. |
| `git branches`; `git branchrename chore/manual-usage` | List all branches; rename the current branch. |
| `git remoteurl`; `git remotestatus` | Print origin URL; query origin's remote status. |
| `git unpushed`; `git lg` | Show commits not on remotes; decorated graph of recent commits. |
| `git todosfind`; `git todoscount`; `git todosnamefiles` | Find TODO/FIXME lines; counts per file; matching filenames. No matches returns nonzero. |
| `git difftool-s`; `git diff-s` | Open staged changes in the configured diff tool; print staged diff. |

Four stored aliases need special treatment:

- `reset` cannot override Git's builtin `reset`. `git reset` runs the builtin,
  not the configured `reset --hard HEAD` alias. To deliberately discard all
  tracked changes, the actual command is `git reset --hard HEAD`.
- `branchesdiffed`, `branchesundiffed`, and `totalcommits` contain PowerShell
  pipelines but are not shell aliases (`!` is missing). They do not work as
  intended in this config. Use these working terminal equivalents:

```bash
git branch --format='%(refname:short)' | grep -F indiff
git branch --format='%(refname:short)' | grep -Fv indiff
git rev-list --all --count
```

This reference covers Appdots' commands; third-party programs have their own
help. For installed script entrypoints and repair procedures, see
[MANUAL.md](MANUAL.md).
