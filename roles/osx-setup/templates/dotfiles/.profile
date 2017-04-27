# {{ ansible_managed }}
# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# Encodage
export LANG="fr_FR.UTF-8"
export LC_COLLATE="fr_FR.UTF-8"
export LC_CTYPE="fr_FR.UTF-8"
export LC_MESSAGES="fr_FR.UTF-8"
export LC_MONETARY="fr_FR.UTF-8"
export LC_NUMERIC="en_US.UTF-8"
export LC_TIME="en_US.UTF-8"

# don't put duplicate lines in the history. See bash(1) for more options
# don't overwrite GNU Midnight Commander's setting of `ignorespace'.
#HISTCONTROL=$HISTCONTROL${HISTCONTROL+:}ignoredups
# ... or force ignoredups and ignorespace
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# Timestamp history
export HISTTIMEFORMAT='%F %T '

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)

# Pour Brew
export PATH=/usr/local/bin:/usr/local/sbin:$HOME/bin:$PATH
# Go
export GOPATH=$HOME/Dropbox/src/gowork
export PATH=$PATH:/usr/local/opt/go/libexec/bin:$GOPATH/bin

# rbenv
export RBENV_ROOT=/usr/local/var/rbenv
eval "$(rbenv init -)"

# Stack / Haskell
# https://docs.haskellstack.org/en/stable/install_and_upgrade/#path
export PATH="$HOME/.local/bin:$PATH"
eval "$(stack --bash-completion-script stack)"

LS_OPTIONS="-G"
export PAGER=less
export EDITOR=vim
export VISUAL=vim
# Options de 'less'
export LESS="-MiR"
# Affiche les accents ISO
export LESSCHARSET=utf-8

alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'
alias cd..='cd ..'
alias more=less
# Affiche la liste de tous les processus tournant en memoire
alias psx='ps aux | ${PAGER}'
# Affiche la liste de tous vos processus
alias psu='ps ux | ${PAGER}'
# Divers alias pour lister le contenu d'un repertoire
# la = comme 'ls' avec les fichiers caches en plus
# ll = tout lister, y compris les fichiers caches
# lm = comme 'll' avec une pause en plus
# dir = affichage long
# dirm = comme 'dirm' avec une pause en plus
alias ls='command ls $LS_OPTIONS -F'
alias la='command ls $LS_OPTIONS -aF'
alias  l='command ls $LS_OPTIONS -lF'
alias ll='command ls $LS_OPTIONS -laF'

# https://gist.github.com/tdd/473838
# http://www.git-attitude.fr/2013/05/22/prompt-git-qui-dechire/

BASH_COMPL_DIR="$(brew --prefix)/etc/bash_completion.d"
if [ -d "$BASH_COMPL_DIR" ]; then
  for f in "$BASH_COMPL_DIR"/*; do
    source $f
  done
fi
# AWS completion
complete -C aws_completer aws

export GIT_PS1_SHOWDIRTYSTATE=1 GIT_PS1_SHOWSTASHSTATE=1 GIT_PS1_SHOWUNTRACKEDFILES=1
export GIT_PS1_SHOWUPSTREAM=verbose GIT_PS1_DESCRIBE_STYLE=branch GIT_PS1_SHOWCOLORHINTS=1
#export PS1='\[\e[0;36m\][\A] \u@\h:\[\e[0m\e[0;32m\]\W\[\e[1;33m\]$(__git_ps1 " (%s)")\[\e[0;37m\] \$\[\e[0m\] '

#export PS1='\u@\h:\W$(__git_ps1 " (%s)")\$ '
#export PROMPT_COMMAND='__git_ps1 "\u@\h:\w" " \\\$ "'
#export PS1='\u@\h:\w$(__git_ps1) \$ '

# Powerline
# https://powerline.readthedocs.io/en/latest/usage/shell-prompts.html#bash-prompt
# http://agperson.com/entry/4081
# https://github.com/jaspernbrouwer/powerline-gitstatus
powerline-daemon -q
POWERLINE_BASH_CONTINUATION=1
POWERLINE_BASH_SELECT=1
powerline_path=$(python -c 'import pkgutil; print pkgutil.get_loader("powerline").filename' 2>/dev/null)
if [[ "$powerline_path" != "" ]]; then
    source ${powerline_path}/bindings/bash/powerline.sh
else
    # Setup your normal PS1 here.
    export PS1='\[\e[0;36m\][\A] \u@\h:\[\e[0m\e[0;32m\]\W\[\e[1;33m\]$(__git_ps1 " (%s)")\[\e[0;37m\] \$\[\e[0m\] '
fi

# pyenv-virtual
if which pyenv-virtualenv-init > /dev/null; then eval "$(pyenv virtualenv-init -)"; fi
. /usr/local/bin/virtualenvwrapper.sh
