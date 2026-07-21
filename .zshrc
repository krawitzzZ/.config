# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

setopt ignore_eof

# hello, it is me
export ME="$(whoami)"

# Path to your oh-my-zsh installation.
export ZSH="/home/${ME}/.oh-my-zsh"

fpath+=~/.zfunc
autoload -Uz compinit
compinit

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
# ZSH_THEME="geoffgarside"
# ZSH_THEME="spaceship"

# SPACESHIP configuration
SPACESHIP_PROMPT_ORDER=(
  battery       # Battery level and status
  # time          # Time stamps section
  user          # Username section
  dir           # Current directory section
  host          # Hostname section
  git           # Git section (git_branch + git_status)
  # package       # Package version
  node          # Node.js section
  # elixir        # Elixir section
  # swift         # Swift section
  golang        # Go section
  # rust          # Rust section
  haskell       # Haskell Stack section # stack is being weird here...
  # docker        # Docker section
  # aws           # Amazon Web Services section
  venv          # virtualenv section
  # conda         # conda virtualenv section
  # pyenv         # Pyenv section
  # kubectl       # Kubectl context section
  line_sep      # Line break
  # vi_mode       # Vi-mode indicator
  jobs          # Background jobs indicator
  char          # Prompt character
)

SPACESHIP_RPROMPT_ORDER=(
  exec_time     # Execution time
  exit_code     # Exit code section
)

SPACESHIP_DIR_TRUNC_REPO=false
SPACESHIP_EXIT_CODE_SHOW=true
SPACESHIP_BATTERY_THRESHOLD=30
SPACESHIP_PROMPT_FIRST_PREFIX_SHOW=true
SPACESHIP_CHAR_PREFIX=' '
SPACESHIP_CHAR_SYMBOL=' '
SPACESHIP_CHAR_SUFFIX=' '
SPACESHIP_DIR_PREFIX=' '
SPACESHIP_BATTERY_PREFIX=' '
SPACESHIP_BATTERY_SUFFIX=''

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
zstyle ':omz:update' frequency 10

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
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
# plugins=(git)
plugins=(
  asdf
  # battery
  colored-man-pages
  git
  # aws
  colorize
  command-not-found
  docker
  docker-compose
  # autoenv
  git-auto-fetch
  golang
  # kubectl
  # minikube
  npm
  cabal
  stack
  rust
  ssh-agent
  zsh-autosuggestions
)

zstyle :omz:plugins:ssh-agent agent-forwarding yes
zstyle :omz:plugins:ssh-agent identities franka gh gh_franka gh gitlab

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vi'
else
  export EDITOR='hx'
fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# handy variables
export CONFIG="$HOME/.config"
export Z="$HOME/.zshrc"

export COLORTERM=truecolor
export TERM=xterm-256color
export GCM_CREDENTIAL_STORE=gpg

export DOCKER_HOST=unix:///run/user/1001/docker.sock
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CONFIG_HOME="$HOME/.config"
export GTK_IM_MODULE="xim"
export NODE_EXTRA_CA_CERTS="$HOME/.local/share/ca-certificates/franka-ca.crt"
export PIP_TRUSTED_HOST=artifactory.fe.lan
export PIP_INDEX_URL=https://artifactory.fe.lan/artifactory/api/pypi/pypi-virtual-all-dev/simple
export PYENV_ROOT="$HOME/.pyenv"
export GOPATH="$HOME/go"
export PATH="$(ruby -e 'puts Gem.user_dir')/bin:$PATH"
export PATH="$GOPATH/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="/snap/bin:$PATH"
export PATH="/usr/local/go/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.local/go/bin:$PATH"
export PATH="$HOME/.npm-global/bin:$PATH"
export PATH="$HOME/.ghcup/bin:$PATH"
export PATH="$HOME/.luarocks/bin:$PATH"
export PATH="$HOME/.opencode/bin:$PATH"
# export PATH="$(npm get prefix)/bin:$PATH"

# pnpm
export PNPM_HOME="$HOME/.local/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac
# pnpm end

### Source functions so they can be used in aliases

# Source every helper script in the zcripts folder (it only holds zsh helpers).
# The (.N) glob qualifier matches regular files only and yields nothing if empty.
if [[ -d "$HOME/.config/zcripts" ]]; then
  for zscript in "$HOME/.config/zcripts"/*(.N); do
    source "$zscript"
  done
  unset zscript
fi

cdl() {
    z "$1"
    ls -FGAhp --color=always
}

race() {
  poetry -C "$HOME/dev/race" run race "$@"
}

# aliases
alias ~="cd ~"
alias ..='cd ../'
alias ls='ls -FGAhp --color=always'
alias cp='cp -iv'
alias mv='mv -iv'
alias please="sudo"
alias mkdir='mkdir -pv'
alias ll='ls -FGlAhp --color=always'
alias c='clear'
alias aptGetUpdate='sudo apt-get update && sudo apt-get upgrade && sudo apt-get autoremove && sudo apt-get autoclean'
alias aptUpdate='sudo apt update && sudo apt upgrade && sudo apt autoremove && sudo apt autoclean'
alias sup='aptGetUpdate && aptUpdate && omz update'
alias path='echo -e ${PATH//:/\\n}'
alias make1mb='mkfile 1m ./1MB.dat'
alias make5mb='mkfile 5m ./5MB.dat'
alias make10mb='mkfile 10m ./10MB.dat'
alias make24mb='mkfile 24m ./24MB.dat'
alias make25mb='mkfile 25m ./25MB.dat'
alias make50mb='mkfile 50m ./50MB.dat'
alias clip='wl-copy'
alias yolo='echo "$(curl -s http://whatthecommit.com/index.txt)"'
alias postgr='docker run -e POSTGRES_PASSWORD=password -p 5432:5432 postgres:latest'

# shorthands
alias gf='git fetch --tags --all --prune -f'
alias gp='gf && git pull'
alias gdd="git describe --tags --always | tr -d '[:space:]'"
alias gddc="gdd | clip"
alias dp='yes | docker system prune --all --force --volumes && yes | docker image prune --all && yes | docker container prune --force && yes | docker volume prune --force'
alias ds='dockerStop'
alias kp='killport'
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias dcr='dcd && dcu'
alias cdr='cd $HOME/dev/race'
alias diff='colordiff'
# alias cat='ccat'
alias y='yarn'
alias p='pnpm'
alias n='npm'
alias r='race'
alias ru='race up'
alias rd='race down'
alias ride='ride -i'
alias ni='npm i'
alias nci='npm ci'
alias nr='npm run'
alias ld='lazydocker'
alias lg='lazygit'
alias h='hx .'
alias hz='hx ~/.zshrc'
alias hc='hx ~/.config'
alias hs='hx ~/.ssh/config'
alias sz='source $Z'

# autostart ssh-agent
if [ -z "$SSH_AUTH_SOCK" ]; then
   # Check for a currently running instance of the agent
   RUNNING_AGENT="$(ps -ax | grep 'ssh-agent -s' | grep -v grep | wc -l | tr -d '[:space:]')"
   if [ "$RUNNING_AGENT" = "0" ]; then
        # Launch a new instance of the agent
        ssh-agent -s &> "$HOME"/.ssh/ssh-agent
   fi
   eval "$(cat "$HOME"/.ssh/ssh-agent)"
fi

[[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh
[[ "$TERM_PROGRAM" == "vscode" ]] && . "$(code --locate-shell-integration-path zsh)"
[ -f "/home/nikita_demin/.ghcup/env" ] && . "/home/nikita_demin/.ghcup/env" # ghcup-env

[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - zsh)"

# . "$HOME/bin/env"
. "$HOME/.cargo/env"

eval "$(starship init zsh)"
eval "$(zoxide init zsh)"

if command -v wt >/dev/null 2>&1; then eval "$(command wt config shell init zsh)"; fi
