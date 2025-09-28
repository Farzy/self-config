# {{ ansible_managed }}
# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

{| if is_wsl2 |}
export LANG=C.UTF-8
{| elif is_macos |}
# You may need to manually set your language environment
# export LANG=en_US.UTF-8
export LANG="fr_FR.UTF-8"
export LC_COLLATE="fr_FR.UTF-8"
export LC_CTYPE="fr_FR.UTF-8"
export LC_MESSAGES="fr_FR.UTF-8"
export LC_MONETARY="fr_FR.UTF-8"
export LC_NUMERIC="en_US.UTF-8"
export LC_TIME="en_US.UTF-8"
{| endif |}

{| if is_debian_family |}
# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi
{| endif |}

# Python / Pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
# eval "$(pyenv virtualenv-init -)"

# Cargo / Rust
if [[ -d "$HOME/.cargo" ]]; then
    . "$HOME/.cargo/env"
fi

{| if is_macos |}
# Homebrew
if [[ -d /opt/homebrew && ! -v HOMEBREW_PREFIX ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -d /usr/local/Homebrew && ! -v HOMEBREW_PREFIX ]]; then
  eval "$(/usr/local/Homebrew/bin/brew shellenv)"
fi
{| endif |}

# Go
if [[ -d "$HOME/go" ]]; then
    # g-install: do NOT edit, see https://github.com/stefanmaric/g
    # Only use these two settings if the Go Version Manager is installed
#     export GOROOT="$HOME/.go"
#     alias ggovm="$GOPATH/bin/g"
    export GOPATH="$HOME/go"
    export PATH="$GOPATH/bin:$PATH"
fi

# rbenv
if type rbenv &>/dev/null; then
    export RBENV_ROOT=/usr/local/var/rbenv
    eval "$(rbenv init -)"
fi

# Krew https://github.com/kubernetes-sigs/krew
if [[ -d "${KREW_ROOT:-$HOME/.krew}/bin" ]]; then
    export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
fi

# Automatic Poetry shell activation/deactivation
_togglePoetryShell() {
  # deactivate shell if pyproject.toml doesn't exist and not in a subdir
  if [[ ! -f "$PWD/pyproject.toml" ]]; then
    if [[ "$POETRY_ACTIVE" == 1 ]]; then
      if [[ "$PWD" != "$pyproject_dir"* ]]; then
        deactivate
        unset POETRY_ACTIVE
      fi
    fi
  fi

  # activate the shell if pyproject.toml exists and is managed by Poetry
  if [[ "$POETRY_ACTIVE" != 1 ]]; then
    if [[ -f "$PWD/pyproject.toml" ]] && grep -q "tool\.poetry" "$PWD/pyproject.toml"; then
      export pyproject_dir="$PWD"
      $(poetry env activate)
      POETRY_ACTIVE=1
    fi
  fi
}

# Automatic UV shell activation/deactivation
_toggleUvShell() {
  # deactivate shell if uv.lock doesn't exist and not in a subdir
  if [[ ! -f "$PWD/uv.lock" ]]; then
    if [[ "$UV_ACTIVE" == 1 ]]; then
      if [[ "$PWD" != "$pyproject_dir"* ]]; then
        deactivate
        unset UV_ACTIVE
      fi
    fi
  fi

  # activate the shell if uv.lock exists
  if [[ "$UV_ACTIVE" != 1 ]]; then
    if [[ -f "$PWD/uv.lock" ]]; then
      export pyproject_dir="$PWD"
      source .venv/bin/activate
      UV_ACTIVE=1
    fi
  fi
}
autoload -U add-zsh-hook
add-zsh-hook chpwd _toggleUvShell
add-zsh-hook chpwd _togglePoetryShell
_toggleUvShell
_togglePoetryShell

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

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
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

{| if is_macos |}
# As the "gnu-utils" plugin already overrides the system ls, we cannot rely on the logic
# inside https://github.com/ohmyzsh/ohmyzsh/blob/master/lib/theme-and-appearance.zsh to
# set colors correctly
eval `gdircolors`
{| endif |}

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(ansible aws gcloud git gnu-utils history kube-ps1 kubectl nvm poetry rust terragrunt uv zsh-autosuggestions)

source $ZSH/oh-my-zsh.sh

# User configuration

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# export MANPATH="/usr/local/man:$MANPATH"

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh

# Bind reverse search key to do pattern search
bindkey '^R' history-incremental-pattern-search-backward

export PAGER=less
export EDITOR=vim
export VISUAL=vim
# Options de 'less'
export LESS="-MiR"
# Affiche les accents ISO
export LESSCHARSET=utf-8

{| if is_macos |}
# Ansible
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES # See https://github.com/ansible/ansible/issues/32499
{| endif |}

export GITHUB_TOKEN={{ github_token }}
{| if integration_personal_laptop |}
export GITHUB_MCP_TOKEN={{ github_mcp_token }}
{| endif |}
{| if is_macos |}
export HOMEBREW_GITHUB_API_TOKEN={{ github_homebrew_token }}
{| endif |}

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
# Git alias "gm" conflicts with GraphicsMagick
unalias gm

# Kubernetes
alias kctx=kubectx
alias kns=kubens
# Display all namespaced resource kinds
function kgetall {
    kubectl api-resources --verbs=list --namespaced -o name \
	    | xargs -n1 kubectl get --show-kind --ignore-not-found "$@"
}
compdef kgetall=kubectl

# Google Cloud
alias gctx=gcloudctx

# Terraform / Terragrunt
alias tf=terraform
alias tg=terragrunt
autoload -U +X bashcompinit && bashcompinit
complete -o nospace -C ${HOMEBREW_PREFIX}/bin/terraform terraform
complete -o nospace -C ${HOMEBREW_PREFIX}/bin/terragrunt terragrunt
compdef tf=terraform
compdef tg=terragrunt

# FZF
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Direnv activation
command -v direnv > /dev/null && eval "$(direnv hook zsh)"

{| if is_macos |}
if [ -d ${HOMEBREW_PREFIX}/Caskroom/google-cloud-sdk/latest/google-cloud-sdk ]; then
    source ${HOMEBREW_PREFIX}/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/completion.zsh.inc
    source ${HOMEBREW_PREFIX}/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.zsh.inc
fi

# Brew completion
if type brew &>/dev/null; then
    if [ -d ${HOMEBREW_PREFIX}/share/zsh/site-functions ]; then
        FPATH=${HOMEBREW_PREFIX}/share/zsh/site-functions:$FPATH
    else
        FPATH=${HOMEBREW_PREFIX}/share/zsh-completions:$FPATH
    fi

    autoload -Uz compinit
    compinit
fi

# UV
if type uv &>/dev/null; then
    eval "$(uv generate-shell-completion zsh)"
fi

# ChatGPT CLI (https://github.com/kardolus/chatgpt-cli)
if command -v chatgpt &>/dev/null; then
    eval "$(chatgpt --set-completions zsh)"
fi

# iTerm2 integration
test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"
{|- endif |}

# Docker completion
if command -v docker &> /dev/null; then
    if [[ -d "${HOME}/.docker/completions" ]]; then
        # The following lines have been added by Docker Desktop to enable Docker CLI completions.
        fpath=(${HOME}/.docker/completions $fpath)
        autoload -Uz compinit
        compinit
    fi
fi

{| if integration_market_pay |}
export DD_API_KEY="{{ mp_dd_api_key }}"
export DD_APP_KEY="{{ mp_dd_app_key }}"
export DD_HOST=https://api.datadoghq.eu
export OVH_APPLICATION_KEY="{{ mp_ovh_application_key }}"
export OVH_APPLICATION_SECRET="{{ mp_ovh_application_secret }}"
export OVH_ENDPOINT=ovh-eu
export OVH_CONSUMER_KEY="{{ mp_ovh_consumer_key }}"
export GITHUB_TOKEN="{{ mp_github_token }}"
export GITHUB_ACCESS_TOKEN="${GITHUB_TOKEN}"
export GH_TOKEN="${GITHUB_TOKEN}"
export GITHUB_OWNER=market-pay-tech
export GITHUB_ORG_OWNER="${GITHUB_OWNER}"
#export GOOGLE_CREDENTIALS=/Users/ffarid/src/market-pay/.secrets/mp-sa-key.json
#export GOOGLE_APPLICATION_CREDENTIALS=""${GOOGLE_CREDENTIALS}""
export GEMINI_API_KEY="{{ gemini_api_key }}"
export TG_PROVIDER_CACHE=1

alias gam="${HOME}/bin/gam7/gam"
{| endif |}
{| if is_wsl2 |}
# The path to your Windows home (If you're using WSL)
export WINDOWS="/mnt/c/Users/farzad.farid"
export desk="${WINDOWS}/Desktop"

# Manually load SSH Agent on WSL2
# Reference: https://docs.github.com/en/authentication/connecting-to-github-with-ssh/working-with-ssh-key-passphrases#auto-launching-ssh-agent-on-git-for-windows
env=~/.ssh/agent.env

agent_load_env () { test -f "$env" && . "$env" >| /dev/null ; }

agent_start () {
    (umask 077; ssh-agent >| "$env")
    . "$env" >| /dev/null ; }

agent_load_env

# agent_run_state: 0=agent running w/ key; 1=agent w/o key; 2=agent not running
agent_run_state=$(ssh-add -l >| /dev/null 2>&1; echo $?)

if [ ! "$SSH_AUTH_SOCK" ] || [ $agent_run_state = 2 ]; then
    agent_start
    ssh-add
elif [ "$SSH_AUTH_SOCK" ] && [ $agent_run_state = 1 ]; then
    ssh-add
fi
unset env
{| endif |}
