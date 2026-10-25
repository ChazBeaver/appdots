# Keep personal repositories under ~/Projects/home

Status: accepted; records the existing design.
Recorded: 2026-10-25.

Personal repository checkouts live at `~/Projects/home/<repo>` on every
machine, on both Linux and macOS. Installers, navigation helpers, and
documentation use this directory consistently.

Each machine installs only the repositories it needs. `~/.dotfiles-env.sh`
is the source of truth for that installed set: each repository's own
installer registers its checkout as an exported `*_DIR` path and maintains
its navigation aliases. A checkout's presence under `~/Projects/home` alone
does not register it as installed.

The shared directory makes personal checkouts predictable across machines.
The environment registry lets commands select installed repositories without
maintaining another list or assuming every personal repository is installed.
Repository updates read the registered paths rather than scanning the
directory. They run explicitly; opening a shell does not pull repositories.

See the [environment documentation](../../README.md#-environment) and
[manual update procedure](../../MANUAL.md#update-installed-repositories).
