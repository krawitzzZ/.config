#!/usr/bin/env bash
# Build and run install.sh scenarios in Docker. Never runs install.sh on the host.
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORKDIR=/tmp/config-install-test
IMAGE=dotfiles-install-test:local

if ! command -v docker >/dev/null 2>&1; then
  echo "error: docker is required for install tests" >&2
  exit 1
fi

rm -rf "$WORKDIR"
mkdir -p "$WORKDIR/context"

git -C "$ROOT" ls-files -z | rsync -a --files-from=- --from0 "$ROOT"/ "$WORKDIR/context"/
rsync -a "$ROOT/.git/" "$WORKDIR/context/.git/"
cp -a "$ROOT/install.sh" "$ROOT/bootstrap.sh" "$WORKDIR/context/"
mkdir -p "$WORKDIR/context/install"
rsync -a "$ROOT/install/" "$WORKDIR/context/install/"

docker build -f "$WORKDIR/context/install/Dockerfile" -t "$IMAGE" "$WORKDIR/context"

run() {
  docker run --rm "$IMAGE" bash -lc "$1"
}

echo "== scenario: idempotent (already at ~/.config) =="
run '
set -euo pipefail
rsync -a /opt/dotfiles/ "$HOME/.config/"
mkdir -p "$HOME/.config/gtk-3.0"
echo keep >"$HOME/.config/gtk-3.0/keep"
bash "$HOME/.config/install.sh" --backup -y --skip-packages
test -f "$HOME/.config/gtk-3.0/keep"
test -L "$HOME/.zshrc"
test "$(readlink -f "$HOME/.zshrc")" = "$(readlink -f "$HOME/.config/.zshrc")"
test -L "$HOME/.gitconfig"
test "$(readlink -f "$HOME/.gitconfig")" = "$(readlink -f "$HOME/.config/.gitconfig_work")"
test -L "$HOME/personal/.gitconfig"
test "$(readlink -f "$HOME/personal/.gitconfig")" = "$(readlink -f "$HOME/.config/.gitconfig_personal")"
test "$(git config --global --get user.email)" = "$(git config --file "$HOME/.config/.gitconfig_work" --get user.email)"
test -f "$HOME/.config/.zenv"
echo OK idempotent
'

echo "== scenario: backup merge from clone =="
run '
set -euo pipefail
mkdir -p "$HOME/repos/dot/.config" "$HOME/.config/zed" "$HOME/.config/gtk-3.0"
echo dummy-zed >"$HOME/.config/zed/old"
echo keep >"$HOME/.config/gtk-3.0/keep"
rsync -a /opt/dotfiles/ "$HOME/repos/dot/.config/"
bash "$HOME/repos/dot/.config/install.sh" --backup -y --skip-packages
test -f "$HOME/.config/zed.bak/old" || test -f "$HOME/.config/zed.bak"
test -f "$HOME/.config/zed/settings.json"
test -f "$HOME/.config/gtk-3.0/keep"
test ! -d "$HOME/repos/dot/.config"
test -L "$HOME/.zshrc"
test -L "$HOME/.gitconfig"
test "$(readlink -f "$HOME/.gitconfig")" = "$(readlink -f "$HOME/.config/.gitconfig_work")"
test -L "$HOME/personal/.gitconfig"
test "$(readlink -f "$HOME/personal/.gitconfig")" = "$(readlink -f "$HOME/.config/.gitconfig_personal")"
test -f "$HOME/.config/.zenv"
echo OK backup
'

echo "== scenario: overwrite merge from clone =="
run '
set -euo pipefail
mkdir -p "$HOME/repos/dot/.config" "$HOME/.config/zed" "$HOME/.config/gtk-3.0"
echo dummy-zed >"$HOME/.config/zed/old"
echo keep >"$HOME/.config/gtk-3.0/keep"
rsync -a /opt/dotfiles/ "$HOME/repos/dot/.config/"
bash "$HOME/repos/dot/.config/install.sh" --overwrite -y --skip-packages
test ! -f "$HOME/.config/zed/old"
test -f "$HOME/.config/zed/settings.json"
test -f "$HOME/.config/gtk-3.0/keep"
test ! -e "$HOME/.config/zed.bak"
echo OK overwrite
'

echo "== scenario: full install.sh + bootstrap.sh =="
run '
set -euo pipefail
rsync -a /opt/dotfiles/ "$HOME/.config/"
bash "$HOME/.config/install.sh" --backup -y
export PATH="$HOME/.local/bin:$HOME/.local/node/bin:$HOME/.local/pnpm:$HOME/.local/pnpm/bin:$HOME/.cargo/bin:$HOME/.local/go/bin:$HOME/go/bin:$HOME/.ghcup/bin:$PATH"
test -L "$HOME/.gitconfig"
command -v rustup
command -v cargo
command -v rustc
command -v zsh
test "$(command -v rg)" = "$HOME/.local/bin/rg"
command -v pnpm
command -v node
command -v npm
command -v starship
command -v zoxide
test -f "$HOME/.fzf.zsh"
test -d "$HOME/.oh-my-zsh"
command -v go
command -v lazygit
command -v lazydocker
test -e "$HOME/.ghcup/env"
command -v wezterm
command -v zed
echo OK full-bootstrap
'

echo "all install tests passed"
