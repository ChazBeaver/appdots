# system/macos/

Run from `~/Projects/home/appdots` on **macOS**. Bootstrap runs these scripts
alphabetically; sync never runs them. Each command below can be used alone
to apply that setting. They write preferences and may restart affected apps.

| Example | Effect and requirements |
| --- | --- |
| `bash system/macos/00-default-shell.sh` | Set installed Zsh as the account login shell, registering it in `/etc/shells` if necessary. May request sudo/chsh authentication; log out/in afterward. |
| `bash system/macos/10-apply-defaults.sh` | Set scrolling direction, mouse/trackpad scaling, and key-repeat preferences. |
| `bash system/macos/20-apply-symbolic-hotkeys.sh` | Write symbolic hotkey IDs 79–82 via PlistBuddy; restart cfprefsd and Dock. Requires the existing symbolic-hotkeys plist. |
| `bash system/macos/30-dock.sh` | Set Dock behavior and restart Dock. If `dockutil` is installed, replace the item layout with the script's app list and Downloads. |
| `bash system/macos/40-login-items.sh` | Add the named apps through System Events; inspect the app list first and allow macOS automation access when requested. |
| `bash system/macos/50-browser.sh` | Print a notice only. This is a placeholder and does not set a browser. |

To customize defaults, edit the desired script, then run only it:

```bash
cd ~/Projects/home/appdots
nvim system/macos/10-apply-defaults.sh
bash system/macos/10-apply-defaults.sh
defaults read -g KeyRepeat
./doctor.sh
```

For the optional Dock layout step:

```bash
brew install dockutil
nvim system/macos/30-dock.sh       # check app paths and desired layout
bash system/macos/30-dock.sh
defaults read com.apple.dock autohide
```

Verify login items in System Settings and select the default browser there
manually until `50-browser.sh` has an implementation. Doctor does not verify
every macOS preference; use the affected UI or `defaults read` to confirm
those values. None of these scripts has a dry run. See the
[manual operations guide](../../MANUAL.md) for shared scripts and recovery.

`00-default-shell.sh` sets zsh as the account login shell. Ghostty also uses
the appdots-managed `ghostty-shell` command, so new terminals consistently
start zsh even before the user logs out after bootstrap.

## Why numbered?

`bootstrap.sh` runs them alphabetically. Prefix numbers let you control order (defaults before dock, dock before login items, etc.) and leave room to insert new steps later (`25-finder.sh` between `20-` and `30-`).

## Imperative, not declarative

Unlike `active/`, these scripts **mutate system state**. They're run once by `bootstrap.sh`; `sync.sh` never touches them. Re-running them on an existing machine is safe (they're idempotent) but unnecessary.
