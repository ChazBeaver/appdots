# Unattended Appdots installation

This is the owner entrypoint for a future Setupdots unattended run. It reuses
`bootstrap.sh` for backups, packages, system scripts, registration, and config
links, then runs `doctor.sh`. Existing interactive bootstrap and routine sync
remain available. The new entrypoint requires `--non-interactive` or `--check`;
calling it without a mode does not install anything.

## Platform prerequisites

- **Arch/Omarchy Linux:** prepare a complete system update and any required
  reboot before starting. Use Omarchy's supported updater on Omarchy, or a
  complete `pacman -Syu` on other supported Arch systems. The installer checks
  the existing package database for known pending updates, Omarchy's reboot
  marker, kernel mismatch, and a replaced running Hyprland executable. A clear
  cached database does **not** establish that remote repositories are current.
- **macOS:** install Homebrew and Python 3 first, prepare non-interactive
  administrative access for casks, and set zsh as the login shell. Homebrew's
  formula/cask installations and `brew update` failures propagate.
- Both platforms require Git, sudo, a writable home directory, and network
  access for packages. Linux checks authorization for declared pacman packages
  and any required login-shell change. Future declared AUR packages require yay.

In unattended mode, Linux package additions use the existing sync databases;
they never run `pacman -Sy`, an OS updater, or a reboot. Privileged operations
use `sudo -n`, and yay receives non-interactive sudo flags. Setupdots must own
the preceding full update/reboot sequence before it can coordinate this path.
Standalone interactive bootstrap now performs a complete supported update and
stops on update failure instead of refreshing the database alone.

This entrypoint covers Appdots' existing responsibilities and existing doctor
checks. It does not yet implement the separately planned Git identity workflow,
font ownership changes, or a full machine reproduction claim.

## Calling contract

```bash
./install.sh --check
./install.sh --non-interactive
# Optional parent directory for this run's private logs:
./install.sh --non-interactive --log-dir /path/outside/git/install-logs
./install.sh --help
```

Run as the intended user, not root. Python 3 is required for this entrypoint.
`--check` runs prerequisites only, without registration, installation, or log
files. It is not a simulation of package resolution or a guarantee of eventual
success. A normal run checks prerequisites again, then installs and verifies.
There is no automatic rollback: after a failure, inspect the log, resolve the
reported prerequisite or drift, and rerun. Successful stages are not skipped
based on a past receipt.

The installer runs stages with stdin closed and no controlling terminal,
disables Git/SSH credential prompts, and stops at the first failed stage.
It never asks for a sudo password or grants privileges. Prepare required Git
credentials, SSH host keys, and non-interactive privilege access before calling
it. A terminal's cached sudo authorization may not apply to a detached process.

Logs default to `$XDG_STATE_HOME/appdots/install-logs/run-*/`, or
`~/.local/state/appdots/install-logs/run-*/`. The printed run directory is
private (0700); `output.log` and `result.json` are private (0600). Keep custom
log directories outside Git. The JSON records the repository, overall exit
code, and each attempted stage's exit code. It is a troubleshooting record,
not proof that later configuration still matches. No environment dump or
shell tracing is enabled. A lock prevents concurrent runs of this repository.

Exit zero means all stages passed. Child failures retain their nonzero exit
status. The entrypoint itself uses 2 for invalid arguments, 3 for a detected
reboot/session-restart prerequisite, 4 for missing prerequisites, 75 for an
already-running installer, and 130/143 for interruption. Other failures are
nonzero; callers must never interpret an unrecognized nonzero value as success.
A failure before log creation is reported on stderr and may have no run record.

Personal files and browser bookmarks are outside this installer. Their transfer
and import remain a separate future Setupdots project milestone.
