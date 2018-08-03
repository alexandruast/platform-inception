# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load. Optionally, if you set this to "random"
# it'll load a random theme each time that oh-my-zsh is loaded.
# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
ZSH_THEME="mh"

# Set list of themes to load
# Setting this variable when ZSH_THEME=random
# cause zsh load theme from this variable instead of
# looking in ~/.oh-my-zsh/themes/
# An empty array have no effect
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion. Case
# sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

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
DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
  gitextras
  history
  kubectl
  last-working-dir
  z
)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# ssh
# export SSH_KEY_PATH="~/.ssh/rsa_id"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# Keyboard settings
bindkey "\033[1~" beginning-of-line
bindkey "\033[4~" end-of-line

# Locale settings
export LC_ALL="en_US.UTF-8"
export LC_CTYPE="en_US.UTF-8"

# Home development environment settings
export PYENV_ROOT="$HOME/.pyenv"
export RBENV_ROOT="$HOME/.rbenv"
export JENV_ROOT="$HOME/.jenv"
export PATH="$PYENV_ROOT/bin:$RBENV_ROOT/bin:$JENV_ROOT/bin:$HOME/.local/bin:$PATH"
eval "$(pyenv init -)"
eval "$(rbenv init -)"
eval "$(jenv init -)"

# This script will load all your *_rsa keys in ~/.ssh directory (configurable)
# You can also place this code block in .bashrc or .zshrc
# It works both in multi user and multi session environments by
# running a single ssh-agent process for each user
# Getting to a process via 'ps -eo' is not bomb proof, but reliable enough
# Warnings:
#  - this is against best practices for ssh keys, where you should
#    load a key only when needed
#  - this can be hacked by anyone with root access, obviously

AGENT_CONFIG="$HOME/.ssh/agent"
IDENTITIES_WILDCARD='*.pem'
if [ ! -f $AGENT_CONFIG ]; then
  touch $AGENT_CONFIG
  chmod 600 $AGENT_CONFIG
fi
ps -eo command,user | grep "ssh-agent \+$(whoami)" > /dev/null || ssh-agent > $AGENT_CONFIG
eval "$(cat $AGENT_CONFIG)" > /dev/null

LOOKUP_DIRS=("$HOME/.ssh")

for i in "${LOOKUP_DIRS[@]}"; do
  if [ "$(find $i -name $IDENTITIES_WILDCARD -type f -print | wc -l)" != "0" ]; then
    eval "ssh-add $i/$IDENTITIES_WILDCARD" > /dev/null 2>&1
  fi
done

ssh-add -l

# Load profile directory
PROFILE_DIR="$HOME/profile.d"
if [ "$(find $PROFILE_DIR/ -type f -printf '.' | wc -c)" -gt 0 ]; then
  source <(cat $PROFILE_DIR/*)
  echo "profiles: $(find $PROFILE_DIR/ -type f -exec basename {} \; | tr '\n' ' ')"
fi
