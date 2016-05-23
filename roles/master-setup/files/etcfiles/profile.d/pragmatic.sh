# Script de configuration bash, exécuté pour les shell interactifs.
# FICHIER GÉRÉ PAR PUPPET. NE PAS MODIFIER.

# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
[ -z "$PS1" ] && return
# Do not run under ZSH
[ -n "$ZSH_VERSION" ] && return

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

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"
export LESS='-MiR'
export LESSCHARSET=utf-8

export LS_OPTIONS="--color=auto"
export PAGER=less
export EDITOR=vim
export VISUAL=vim

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

#if [ "$color_prompt" = yes ]; then
#    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
#else
#    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
#fi
unset color_prompt force_color_prompt

# https://gist.github.com/tdd/473838
# http://www.git-attitude.fr/2013/05/22/prompt-git-qui-dechire/

#if [ -d $(brew --prefix)/etc/bash_completion.d ]; then
#  source $(brew --prefix)/etc/bash_completion.d/git-completion.bash
#  source $(brew --prefix)/etc/bash_completion.d/git-prompt.sh
#  source $(brew --prefix)/etc/bash_completion.d/mosh
#fi

export GIT_PS1_SHOWDIRTYSTATE=1 GIT_PS1_SHOWSTASHSTATE=1 GIT_PS1_SHOWUNTRACKEDFILES=1
export GIT_PS1_SHOWUPSTREAM=verbose GIT_PS1_DESCRIBE_STYLE=branch GIT_PS1_SHOWCOLORHINTS=1
export PS1='\[\e[0;36m\][\A] \u@\h:\[\e[0m\e[0;32m\]\W\[\e[1;33m\]$(__git_ps1 " (%s)")\[\e[0;37m\] \$\[\e[0m\] '

#export PS1='\u@\h:\W$(__git_ps1 " (%s)")\$ '
#export PROMPT_COMMAND='__git_ps1 "\u@\h:\w" " \\\$ "'
#export PS1='\u@\h:\w$(__git_ps1) \$ '

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# Affiche la liste de tous les processus tournant en memoire
alias psx='ps aux | ${PAGER}'
# Affiche la liste de tous vos processus
alias psu='ps ux | ${PAGER}'
# some more ls aliases
alias ls='command ls $LS_OPTIONS -F'
alias la='command ls $LS_OPTIONS -AF'
alias  l='command ls $LS_OPTIONS -lF'
alias ll='command ls $LS_OPTIONS -lAF'
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias more=less

umask 022



# Fonction shell qui permet de récupérer ssh-agent dans un screen
# détaché et rattaché à un ssh différent.
ssh-screen-auth () 
{ 
    local SCREENPID SOCK DISP;
    local -a SCREENPIDS;
    SCREENPIDS=($(pgrep -f "screen -(r|dr|DR)" -u $UID));
    if [ ${#SCREENPIDS[*]} -ne 1 ]; then
        echo "Il y a plusieurs sessions screen en cours pour l'utilisateur ${USER}(${UID})";
        return 1;
    fi;
    SCREENPID=${SCREENPIDS[0]};
    SOCK=$(sudo cat /proc/${SCREENPID}/environ | tr "\0" "\n" | grep SSH_AUTH_SOCK);
    if [ -n "${SOCK}" ]; then
        eval $SOCK;
        export SSH_AUTH_SOCK;
    fi;
    DISP=$(sudo cat /proc/${SCREENPID}/environ | tr "\0" "\n" | grep DISPLAY);
    if [ -n "${DISP}" ]; then
        eval $DISP;
        export DISPLAY;
    fi
}
