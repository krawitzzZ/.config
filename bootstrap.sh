#!/usr/bin/env bash
# Install tools this checkout expects. Idempotent.
set -euo pipefail

SKIP_APPS=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-apps) SKIP_APPS=1 ;;
    -h|--help)
      echo "Usage: bootstrap.sh [--skip-apps]"
      echo "  --skip-apps  skip rust/node/go/ghcup/wezterm/zed"
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      exit 2
      ;;
  esac
  shift
done

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=install/common.sh
. "$SCRIPT_DIR/install/common.sh"

mkdir -p "$HOME/.local/bin" "$HOME/.local/share/fonts" "$HOME/go/bin"
export PNPM_HOME="${PNPM_HOME:-$HOME/.local/pnpm}"
export PATH="$HOME/.local/bin:$HOME/.local/node/bin:$PNPM_HOME:$PNPM_HOME/bin:$HOME/.cargo/bin:$HOME/.local/go/bin:$HOME/go/bin:$HOME/.ghcup/bin:$PATH"

# --- apt ---
APT_PACKAGES=(
  zsh git curl wget unzip ca-certificates fontconfig xz-utils
  build-essential wl-clipboard colordiff lsof rsync gnupg
  libatomic1 python3 openssl
)

need_apt=()
for pkg in "${APT_PACKAGES[@]}"; do
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    need_apt+=("$pkg")
  fi
done
if [[ ${#need_apt[@]} -gt 0 ]]; then
  run_root apt-get update -y
  run_root DEBIAN_FRONTEND=noninteractive apt-get install -y "${need_apt[@]}"
fi

# --- oh-my-zsh ---
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}
if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
  git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

# --- starship / zoxide / fzf ---
if ! have starship; then
  curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"
fi

if ! have zoxide; then
  curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
fi

if [[ ! -f "$HOME/.fzf.zsh" ]]; then
  if [[ ! -d "$HOME/.fzf" ]]; then
    git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
  fi
  "$HOME/.fzf/install" --all --no-bash --no-fish --no-update-rc
fi

# --- nerd fonts used by wezterm / zed / fontconfig ---
FONT_DIR=$HOME/.local/share/fonts
install_nerd_zip() {
  local name=$1
  local marker=$2
  if fc-list | grep -qi "$marker"; then
    return 0
  fi
  local tmp
  tmp=$(mktemp -d)
  curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${name}.zip" -o "$tmp/${name}.zip"
  unzip -qo "$tmp/${name}.zip" -d "$FONT_DIR/${name}"
  rm -rf "$tmp"
}

install_nerd_zip VictorMono "VictorMono Nerd Font"
install_nerd_zip JetBrainsMono "JetBrainsMono Nerd Font"
install_nerd_zip FiraCode "FiraCode Nerd Font"
install_nerd_zip NerdFontsSymbolsOnly "Symbols Nerd Font"
fc-cache -f >/dev/null

# --- ripgrep (latest GitHub release) ---
rg_tag=$(github_latest_tag https://github.com/BurntSushi/ripgrep/releases/latest)
if ! have rg || ! rg --version 2>/dev/null | head -n1 | grep -Fq "$rg_tag"; then
  case "$(dpkg_arch)" in
    amd64) rg_target=x86_64-unknown-linux-musl ;;
    arm64) rg_target=aarch64-unknown-linux-musl ;;
    *)
      echo "error: no ripgrep release archive for $(dpkg_arch)" >&2
      exit 1
      ;;
  esac
  rg_tmp=$(mktemp -d)
  rg_archive="ripgrep-${rg_tag}-${rg_target}.tar.gz"
  curl -fsSL "https://github.com/BurntSushi/ripgrep/releases/download/${rg_tag}/${rg_archive}" \
    -o "$rg_tmp/$rg_archive"
  tar -xzf "$rg_tmp/$rg_archive" -C "$rg_tmp"
  install -m 755 "$rg_tmp/ripgrep-${rg_tag}-${rg_target}/rg" "$HOME/.local/bin/rg"
  rm -rf "$rg_tmp"
fi

if [[ $SKIP_APPS -eq 1 ]]; then
  echo "bootstrap: skipped rust/node/go/ghcup/wezterm/zed (--skip-apps)"
  echo "bootstrap finished"
  exit 0
fi

# --- rustup ---
if ! have rustup; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi
# shellcheck disable=SC1091
[[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"

# --- pnpm + Node.js LTS (bundled npm) ---
# shellcheck source=install/node.sh
. "$SCRIPT_DIR/install/node.sh"

# --- go + lazygit / lazydocker ---
if ! have go; then
  go_ver=$(curl -fsSL https://go.dev/VERSION?m=text | head -n1)
  tmp=$(mktemp)
  curl -fsSL "https://go.dev/dl/${go_ver}.linux-$(dpkg_arch).tar.gz" -o "$tmp"
  rm -rf "$HOME/.local/go"
  tar -C "$HOME/.local" -xzf "$tmp"
  rm -f "$tmp"
fi
export PATH="$HOME/.local/go/bin:$HOME/go/bin:$PATH"
if ! have go && [[ -x "$HOME/.local/go/bin/go" ]]; then
  export PATH="$HOME/.local/go/bin:$PATH"
fi
if ! have lazygit; then
  go install github.com/jesseduffield/lazygit@latest
fi
if ! have lazydocker; then
  go install github.com/jesseduffield/lazydocker@latest
fi

# --- ghcup ---
if [[ ! -e "$HOME/.ghcup/env" ]]; then
  BOOTSTRAP_HASKELL_NONINTERACTIVE=1 \
  BOOTSTRAP_HASKELL_INSTALL_HLS=0 \
  BOOTSTRAP_HASKELL_ADJUST_BASHRC=0 \
    curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
fi

# --- wezterm ---
if ! have wezterm; then
  run_root mkdir -p /usr/share/keyrings /etc/apt/sources.list.d
  curl -fsSL https://apt.fury.io/wez/gpg.key | run_root gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
  echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' |
    run_root tee /etc/apt/sources.list.d/wezterm.list >/dev/null
  run_root chmod 644 /usr/share/keyrings/wezterm-fury.gpg
  run_root apt-get update -y
  run_root DEBIAN_FRONTEND=noninteractive apt-get install -y wezterm
fi

# --- zed ---
if ! have zed; then
  curl -f https://zed.dev/install.sh | sh
fi

if have zsh && [[ "$(getent passwd "$(id -un)" | cut -d: -f7)" != "$(command -v zsh)" ]]; then
  if chsh -s "$(command -v zsh)" >/dev/null 2>&1; then
    echo "default shell set to zsh"
  fi
fi

echo "bootstrap finished"
