

# Commands that should be applied only for interactive shells.
[[ $- == *i* ]] || return

# Zsh is the appdots-managed interactive shell. This is a defensive handoff
# for terminals that were launched with Bash before the login-shell or
# terminal-specific configuration converged.
if command -v zsh >/dev/null 2>&1; then
  export SHELL="$(command -v zsh)"
  exec "$SHELL"
fi

HISTFILESIZE=100000
HISTSIZE=10000

shopt -s histappend
shopt -s checkwinsize
shopt -s extglob
shopt -s globstar
shopt -s checkjobs

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias 000='chmod -R 000'
alias 644='chmod -R 644'
alias 666='chmod -R 666'
alias 755='chmod -R 755'
alias 777='chmod -R 777'
alias bd='cd "$OLDPWD"'
alias cd..='cd ..'
alias cl='clear'
alias dot='cd /home/chaz/.dotfiles'
alias h='history | grep '
alias home='cd ~'
alias la='ls -Alh'
alias labc='ls -lap'
alias lc='ls -lcrh'
alias ld='ls -l | egrep '\''^d'\'''
alias lf='ls -l | egrep -v '\''^d'\'''
alias lk='ls -lSrh'
alias ll='ls -Fls'
alias lm='ls -alh |more'
alias lr='ls -lRh'
alias ls='ls -aFh --color=always'
alias lt='ls -ltrh'
alias lu='ls -lurh'
alias lw='ls -xAh'
alias lx='ls -lXBh'
alias matrix='cmatrix -b -s -u 6'
alias mx='chmod a+x'
alias rmd='/bin/rm  --recursive --force --verbose '
alias v='nvim .'
alias vim='nvim'
alias vimdiff='nvim -d'
