# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

setopt ignore_eof
setopt rm_star_silent

# hello, it is me
export ME="$(whoami)"

# Path to your oh-my-zsh installation.
export ZSH="/home/${ME}/.oh-my-zsh"

# Completions in ~/.zfunc; oh-my-zsh runs compinit once after this.
fpath+=~/.zfunc

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
plugins=(
  # battery
  colored-man-pages
  git
  # aws
  colorize
  command-not-found
  docker
  docker-compose
  # autoenv
  # git-auto-fetch
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
zstyle :omz:plugins:ssh-agent identities franka gh gh_franka gitlab

source "$ZSH"/oh-my-zsh.sh

# User configuration
# Env/PATH for all zsh (including GUI) lives in ~/.zshenv.

# export MANPATH="/usr/local/man:$MANPATH"
# export ARCHFLAGS="-arch x86_64"

export CONFIG="$HOME/.config"
export Z="$HOME/.zshrc"
export PI="192.168.0.15"

export GTK_IM_MODULE="xim"

_gem_cache="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/gem-user-bin"
_gem_bin=
[[ -r "$_gem_cache" ]] && _gem_bin="$(<"$_gem_cache")"
if [[ -z "$_gem_bin" || ! -d "$_gem_bin" ]] && command -v ruby >/dev/null 2>&1; then
  _gem_bin="$(ruby -e 'print Gem.user_dir' 2>/dev/null)/bin"
  mkdir -p "${_gem_cache:h}"
  print -r -- "$_gem_bin" >|"$_gem_cache"
fi
[[ -d "$_gem_bin" ]] && PATH="$_gem_bin:$PATH"
unset _gem_cache _gem_bin

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
alias clip='wl-copy'
alias yolo='echo "$(curl -s http://whatthecommit.com/index.txt)"'

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
alias p='pnpm'
alias n='npm'
alias ru='race up'
alias rd='race down'
alias rc='race clean -y'
alias rr='rd && ru'
alias f='franka'
alias fj='franka jenkins'
alias fl='franka locks'
alias fid='franka install-dev'
alias ride='ride -i'
alias ni='npm i'
alias nci='npm ci'
alias nr='npm run'
alias ld='lazydocker'
alias lg='lazygit'
alias zz='zed -n'
alias zz.='zed -n .'
alias e='${EDITOR:-nevi}'
alias sr='serie'
alias v='nevi'
alias v.='nevi .'
alias vz='nevi ~/.zshrc'
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

command -v pyenv >/dev/null 2>&1 && eval "$(pyenv init - zsh)"

eval "$(starship init zsh)"
eval "$(zoxide init zsh)"

if command -v wt >/dev/null 2>&1; then eval "$(command wt config shell init zsh)"; fi
