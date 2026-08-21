# Always sourced (login, non-interactive, GUI-spawned zsh). Keep this file
# cheap: no eval, no agents, no prompt init. Interactive-only setup stays in
# ~/.zshrc.

# Local secrets/env (.env syntax).
if [[ -f "$HOME/.config/.zenv" ]]; then
  set -a
  source "$HOME/.config/.zenv"
  set +a
fi

export LANG=en_US.UTF-8
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vi'
else
  export EDITOR='nevi'
fi

export COLORTERM=truecolor
export GCM_CREDENTIAL_STORE=gpg
export DOCKER_HOST="unix://${XDG_RUNTIME_DIR:-/run/user/${UID}}/docker.sock"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CONFIG_HOME="$HOME/.config"
export NODE_EXTRA_CA_CERTS="$HOME/.local/share/ca-certificates/franka-ca.crt"
export PIP_TRUSTED_HOST=artifactory.fe.lan
export PIP_INDEX_URL=https://artifactory.fe.lan/artifactory/api/pypi/pypi-virtual-all-dev/simple
export PYENV_ROOT="$HOME/.pyenv"
export GOPATH="$HOME/go"
export PNPM_HOME="$HOME/.local/pnpm"

# GNOME keyring no longer serves SSH (pkcs11/secrets only); session still
# exports $XDG_RUNTIME_DIR/keyring/ssh which nothing listens on. Prefer gcr.
if [[ "$SSH_AUTH_SOCK" == */keyring/ssh && -S "${XDG_RUNTIME_DIR}/gcr/ssh" ]]; then
  export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR}/gcr/ssh"
fi

[[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"
[[ -f "$HOME/.ghcup/env" ]] && . "$HOME/.ghcup/env"

_path_prepend() {
  [[ -d "$1" ]] || return
  case ":$PATH:" in
    *":$1:"*) ;;
    *) PATH="$1:$PATH" ;;
  esac
}

# Last prepended wins (front of PATH). Mirrors the old ~/.zshrc order.
_path_prepend "$GOPATH/bin"
_path_prepend "$HOME/.cargo/bin"
_path_prepend "/snap/bin"
_path_prepend "/usr/local/go/bin"
_path_prepend "$HOME/.local/bin"
_path_prepend "$HOME/.local/node/bin"
_path_prepend "$HOME/.local/go/bin"
_path_prepend "$HOME/.npm-global/bin"
_path_prepend "$HOME/.ghcup/bin"
_path_prepend "$HOME/.luarocks/bin"
_path_prepend "$HOME/.opencode/bin"
_path_prepend "$PNPM_HOME/bin"
_path_prepend "$PYENV_ROOT/bin"
_path_prepend "$PYENV_ROOT/shims"
export PATH
unset -f _path_prepend
