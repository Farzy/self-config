# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Cargo / Rust
export PATH="$HOME/.cargo/bin:$PATH"

# Python 3.8
export PATH="/usr/local/opt/python@3.8/bin:$PATH"

# Pour Brew
export PATH=/usr/local/bin:/usr/local/sbin:$HOME/bin:$PATH

# Go
export PATH=$PATH:${HOME}/src/GO/bin

# rbenv
if type rbenv &>/dev/null; then
    export RBENV_ROOT=/usr/local/var/rbenv
    eval "$(rbenv init -)"
fi

# Krew https://github.com/kubernetes-sigs/krew
if [[ -d "${KREW_ROOT:-$HOME/.krew}/bin" ]]; then
    export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
fi

# Terraform 0.12
export PATH="/usr/local/opt/terraform@0.12/bin:$PATH"

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes

# See https://github.com/romkatv/powerlevel10k
# git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel10k
ZSH_THEME="powerlevel10k/powerlevel10k"

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to automatically update without prompting.
# DISABLE_UPDATE_PROMPT="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS=true

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
HIST_STAMPS="yyyy-mm-dd"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# As the "gnu-utils" plugin already overrides the system ls, we cannot rely on the logic
# inside https://github.com/ohmyzsh/ohmyzsh/blob/master/lib/theme-and-appearance.zsh to
# set colors correctly
eval `gdircolors`

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git ansible pipenv gcloud gnu-utils history kube-ps1 kubectl nvm cargo rust rustup zsh-autosuggestions)

source $ZSH/oh-my-zsh.sh

# User configuration

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8
export LANG="fr_FR.UTF-8"
export LC_COLLATE="fr_FR.UTF-8"
export LC_CTYPE="fr_FR.UTF-8"
export LC_MESSAGES="fr_FR.UTF-8"
export LC_MONETARY="fr_FR.UTF-8"
export LC_NUMERIC="en_US.UTF-8"
export LC_TIME="en_US.UTF-8"

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

export PAGER=less
export EDITOR=vim
export VISUAL=vim
# Options de 'less'
export LESS="-MiR"
# Affiche les accents ISO
export LESSCHARSET=utf-8

# Ansible
export ANSIBLE_VAULT_PASSWORD_FILE=~/.ansible-vault-password
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES # See https://github.com/ansible/ansible/issues/32499

export NPM_TOKEN={{ npm_token }}
export NESTOR_NPM_TOKEN=${NPM_TOKEN}
export GITHUB_TOKEN={{ github_token }}
export NESTOR_GITHUB_TOKEN=${GITHUB_TOKEN}
export NGINXAPIKEY="{{ nginx_api_key }}"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'
# Affiche la liste de tous les processus tournant en memoire
alias psx='ps aux | ${PAGER}'
# Affiche la liste de tous vos processus
alias psu='ps ux | ${PAGER}'

alias kctx=kubectx
alias gctx=gcloudctx

# Disable temporarily as this messes up Kapten Playbook that call kubectl
#alias ansible-playbook="no_proxy='*' command ansible-playbook" # See https://bugs.python.org/issue30385

# Brew completion
if type brew &>/dev/null; then
    FPATH=$(brew --prefix)/share/zsh-completions:$FPATH

    autoload -Uz compinit
    compinit
fi

# Please define KAPTEN_SRC to the absolute path where you host your projects' sources.
if [ -d "${HOME}/src/Kapten" ]; then
    KAPTEN_SRC="${HOME}/src/Kapten"
elif [ -d "${HOME}/src" ]; then
    KAPTEN_SRC="${HOME}/src"
fi
export KAPTEN_SRC

if [[ -n "${KAPTEN_SRC}" ]]; then
    # Reload repository not more than once a day
    TIME_MARKER=/tmp/kapten-src-last-update.txt
    if [[ ! -f "${TIME_MARKER}" || $(( $(date +%s) - $(date -r "${TIME_MARKER}" +%s) )) -gt 86400 ]]; then
        #echo -n "Updating k8s-helper repository… "
        # Check network connectivity, ignore all if computer is offline
        curl --silent --connect-timeout 0.5 https://github.com >/dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            if [[ ! -d ${KAPTEN_SRC}/devops-scripts ]]; then
            git -C ${KAPTEN_SRC} clone git@github.com:transcovo/devops-scripts.git
            fi
            git -C ${KAPTEN_SRC}/devops-scripts pull --rebase >/dev/null 2>&1
            touch "${TIME_MARKER}"
        fi
        #echo "done."
    fi

    # Source helper only if it exists, fail silently otherwise
    if [[ -f "${KAPTEN_SRC}/devops-scripts/kubernetes/k8s-helper.sh" ]]; then
        source "${KAPTEN_SRC}/devops-scripts/kubernetes/k8s-helper.sh"
    fi
else
    echo "Shell variable KAPTEN_SRC is not defined, cannot create shell functions." 2>&1
fi
