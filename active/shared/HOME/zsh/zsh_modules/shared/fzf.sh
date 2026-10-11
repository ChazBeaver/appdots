# FZF Configs
export FZF_DEFAULT_OPTS="
--layout=reverse
--info=inline
--height=80%
--multi
--preview-window=:hidden
--preview '([[ -f {} ]] && (bat --style=numbers --color=always {} || cat {})) || ([[ -d {} ]] && (tree -C {} | less)) || echo {} 2> /dev/null | head -200'
--color='hl:148,hl+:154,pointer:032,marker:010,bg+:237,gutter:008'
--prompt='∼ ' --pointer='▶' --marker='✓'
--bind '?:toggle-preview'
--bind 'ctrl-a:select-all'
--bind 'ctrl-y:execute-silent(echo -n {+} | { wl-copy 2>/dev/null || pbcopy 2>/dev/null || xclip -selection clipboard 2>/dev/null || xsel --clipboard --input 2>/dev/null })'
--bind 'ctrl-e:execute(echo {+} | xargs -o vim)'
--bind 'ctrl-v:execute(code {+})'
"

# Find system directories
fda() {
  local root="${1:-$HOME}"
  [[ "$1" == "--all" ]] && root="/"

  local max="${FD_MAX_RESULTS:-150000}"
  local dir

  dir="$(
    command find "$root" \
      \( -path /proc -o -path /sys -o -path /dev -o -path /run \) -prune -o \
      -type d -print 2>/dev/null \
    | head -n "$max" \
    | fzf --preview 'tree -C -L 2 {} 2>/dev/null | head -200' +m
  )" || return

  cd -- "$dir"
}

_ad_register fda fzf 'fda [ROOT|--all]' 'Choose a directory under HOME, a supplied root, or the full filesystem.' run fd \
    'When: You need to find a directory below ~/Projects.
The search includes hidden directories.
The directory ~/Projects/example must exist for this example.
Example:
  fda ~/Projects
Result: The function searches ~/Projects and opens the fzf picker.
Select the example directory with the arrow keys.
Press Enter to change to that directory.
Use fda without a path to search your home directory.
Use fda --all to start the search at /.
The search skips /proc, /sys, /dev, and /run.

The picker shows a maximum of 150000 directory paths by default.
Set FD_MAX_RESULTS to change this limit, for example:
  FD_MAX_RESULTS=200000 fda ~/Projects'

# Find a file to edit
fe() {
    local file
    file=$(find ${1:-.} -type f 2> /dev/null | fzf --preview 'bat --style=numbers --color=always {} || cat {}' +m) && [ -n "$file" ] && nvim "$file"
}

_ad_register fe fzf 'fe [ROOT]' 'Choose a file below a directory and open it in Neovim.' run '' \
    'When: You need to find and edit a file below the current directory.
The file ./foo.txt must exist for this example.
Example:
  fe .
Result: The function searches for files and opens the fzf picker.
Type part of a file name to reduce the list.
Select ./foo.txt with the arrow keys.
Press Enter to open the file in Neovim.
Use fe without a path to search the current directory.
Use fe ~/Projects to search below ~/Projects.'

# Find relative directories
fcd() {
  local dir
  dir=$(find "${1:-.}" -type d -not -path '*/.*' 2>/dev/null | fzf +m) && cd "$dir"
}

_ad_register fcd fzf 'fcd [ROOT]' 'Choose a non-hidden directory below a root and change into it.' run '' \
    'When: You need to change to a directory below ~/Projects.
The directory ~/Projects/example must exist for this example.
Example:
  fcd ~/Projects
Result: The function searches ~/Projects and opens the fzf picker.
The list excludes paths that contain a hidden directory.
Select the example directory with the arrow keys.
Press Enter to change to that directory.
Use fcd without a path to search the current directory.'
