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

_ad_register fda fzf 'fda [ROOT|--all]' 'Find directories, even hidden; Search from HOME, a supplied root, or /, then change to the selected directory.' run fd \
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
Directories beyond that limit are absent from the picker.
Set FD_MAX_RESULTS to change this limit, for example:
  FD_MAX_RESULTS=200000 fda ~/Projects'

# Find a file to edit
fe() {
    local file
    file=$(find ${1:-.} -type f 2> /dev/null | fzf --preview 'bat --style=numbers --color=always {} || cat {}' +m) && [ -n "$file" ] && nvim "$file"
}

_ad_register fe fzf 'fe [ROOT]' 'Find a file to edit; Search below a directory and open the selected file in Neovim.' run '' \
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

_ad_register fcd fzf 'fcd [ROOT]' 'Find directories, skip hidden; Search below the current or supplied directory and change to the selected path.' run '' \
    'When: You need to change to a directory below ~/Projects.
The directory ~/Projects/example must exist for this example.
Example:
  fcd ~/Projects
Result: The function searches ~/Projects and opens the fzf picker.
The list excludes paths that contain a hidden directory.
Select the example directory with the arrow keys.
Press Enter to change to that directory.
Use fcd without a path to search the current directory.'

# Search History using FZF
fh() {
  local cmd
  cmd=$(fc -lnr 1 | fzf --tac) || return
  print -z -- "$cmd"
}

_ad_register fh fzf fh 'Find a history command; Search the current shell history and put the selected command at the prompt.' view hf \
    'When: You need to find a command in the history of the current shell.
Example:
  fh
Result: The function reads the shell history and opens the fzf picker.
Type part of the command to reduce the list.
Select a command with the arrow keys.
Press Enter to put the selected command at the shell prompt.
Check the command before you run it.

Press Ctrl-Y to copy the selected command to the clipboard.
The picker stays open after the copy.
Press Esc to close the picker without a selection.'
