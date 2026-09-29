export KITTY_CONFIG_DIRECTORY="$HOME/.config/kitty"

# appdots links bin/shared/* and bin/macos/* into here (see sync.sh); without
# this the `theme` command and everything else there is "command not found".
[[ ":$PATH:" != *":$HOME/.local/bin:"* ]] && export PATH="$HOME/.local/bin:$PATH"
