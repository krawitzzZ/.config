#!/usr/bin/env bash
# Merge this checkout into ~/.config, then symlink shell/git identity files.
# Never intended to replace an entire ~/.config tree (Ubuntu always has one).
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: install.sh [--backup|--overwrite] [-y] [--skip-packages] [--skip-apps]

  --backup       On name collisions, rename existing DST/name to name.bak
  --overwrite    On name collisions, replace existing DST/name
  -y             Non-interactive (requires --backup or --overwrite)
  --skip-packages
                 Do not run bootstrap.sh at all
  --skip-apps
                 Run bootstrap.sh --skip-apps (shell/fonts/rg only;
                 skip rust, node, go, ghcup, wezterm, zed)
EOF
}

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SRC=$SCRIPT_DIR
DST=${HOME}/.config
CONFLICT_MODE=
NONINTERACTIVE=0
SKIP_PACKAGES=0
SKIP_APPS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --backup) CONFLICT_MODE=backup ;;
    --overwrite) CONFLICT_MODE=overwrite ;;
    -y|--yes) NONINTERACTIVE=1 ;;
    --skip-packages) SKIP_PACKAGES=1 ;;
    --skip-apps) SKIP_APPS=1 ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [[ ! -d "$SRC/.git" || ! -f "$SRC/.zshrc" ]]; then
  echo "error: $SRC does not look like this dotfiles checkout" >&2
  exit 1
fi

if [[ $NONINTERACTIVE -eq 1 && -z "$CONFLICT_MODE" ]]; then
  echo "error: -y requires --backup or --overwrite" >&2
  exit 2
fi

backup_path() {
  local p=$1 bak=${1}.bak i=1
  while [[ -e "$bak" || -L "$bak" ]]; do
    bak=${p}.bak.$i
    i=$((i + 1))
  done
  printf '%s\n' "$bak"
}

same_inode() {
  local a=$1 b=$2
  [[ -e "$a" && -e "$b" ]] || return 1
  local ia ib
  ia=$(stat -c '%d:%i' "$a" 2>/dev/null) || return 1
  ib=$(stat -c '%d:%i' "$b" 2>/dev/null) || return 1
  [[ "$ia" == "$ib" ]]
}

resolve_conflict() {
  local dest=$1
  case "$CONFLICT_MODE" in
    backup)
      local bak
      bak=$(backup_path "$dest")
      mv "$dest" "$bak"
      echo "backed up $dest -> $bak"
      ;;
    overwrite)
      rm -rf "$dest"
      echo "removed $dest"
      ;;
    *)
      echo "error: no conflict mode for $dest" >&2
      exit 1
      ;;
  esac
}

choose_conflict_mode() {
  local -n _conflicts=$1
  [[ ${#_conflicts[@]} -eq 0 ]] && return 0
  [[ -n "$CONFLICT_MODE" ]] && return 0

  if [[ $NONINTERACTIVE -eq 1 || ! -t 0 ]]; then
    echo "error: collisions need --backup or --overwrite: ${_conflicts[*]}" >&2
    exit 2
  fi

  echo "These already exist under $DST:"
  printf '  %s\n' "${_conflicts[@]}"
  echo -n "[o]verwrite / [b]ackup as NAME.bak / [a]bort? "
  local ans
  read -r ans
  case "$ans" in
    o|O|overwrite) CONFLICT_MODE=overwrite ;;
    b|B|backup) CONFLICT_MODE=backup ;;
    *)
      echo "aborted"
      exit 1
      ;;
  esac
}

ensure_symlink() {
  local target=$1 dest=$2
  mkdir -p "$(dirname -- "$dest")"
  local want
  want=$(readlink -f -- "$target")

  if [[ -L "$dest" ]]; then
    local cur
    cur=$(readlink -f -- "$dest" || true)
    if [[ "$cur" == "$want" ]]; then
      return 0
    fi
  fi

  if [[ -e "$dest" || -L "$dest" ]]; then
    if [[ -z "$CONFLICT_MODE" ]]; then
      if [[ $NONINTERACTIVE -eq 1 || ! -t 0 ]]; then
        echo "error: $dest exists; pass --backup or --overwrite" >&2
        exit 2
      fi
      echo -n "$dest exists. [o]verwrite / [b]ackup / [a]bort? "
      local ans
      read -r ans
      case "$ans" in
        o|O) CONFLICT_MODE=overwrite ;;
        b|B) CONFLICT_MODE=backup ;;
        *)
          echo "aborted"
          exit 1
          ;;
      esac
    fi
    resolve_conflict "$dest"
  fi

  ln -sfn "$target" "$dest"
  echo "linked $dest -> $target"
}

SRC_REAL=$(readlink -f -- "$SRC")
DST_REAL=$(readlink -f -- "$DST" 2>/dev/null || true)

if [[ -n "$DST_REAL" && "$SRC_REAL" == "$DST_REAL" ]]; then
  echo "already living at $DST; skipping merge"
else
  mkdir -p "$DST"

  if [[ -d "$DST/.git" ]] && ! same_inode "$SRC/.git" "$DST/.git"; then
    echo "error: $DST/.git exists and is not this checkout" >&2
    exit 1
  fi

  shopt -s dotglob nullglob
  names=()
  for path in "$SRC"/*; do
    names+=("$(basename -- "$path")")
  done
  shopt -u dotglob nullglob

  conflicts=()
  for name in "${names[@]}"; do
    [[ "$name" == "." || "$name" == ".." ]] && continue
    if [[ -e "$DST/$name" || -L "$DST/$name" ]]; then
      if same_inode "$SRC/$name" "$DST/$name"; then
        continue
      fi
      conflicts+=("$name")
    fi
  done

  choose_conflict_mode conflicts

  for name in "${conflicts[@]}"; do
    resolve_conflict "$DST/$name"
  done

  if command -v rsync >/dev/null 2>&1; then
    rsync -a "$SRC"/ "$DST"/
  else
    shopt -s dotglob
    cp -a "$SRC"/. "$DST"/
    shopt -u dotglob
  fi
  echo "copied checkout into $DST"

  if [[ "$SRC_REAL" != "$(readlink -f -- "$DST")" ]]; then
    rm -rf "$SRC"
    echo "removed $SRC"
  fi
fi

mkdir -p "$HOME/personal"
ensure_symlink "$DST/.zshrc" "$HOME/.zshrc"
ensure_symlink "$DST/.gitconfig_personal" "$HOME/personal/.gitconfig"
ensure_symlink "$DST/.gitconfig_work" "$HOME/.gitconfig"

if [[ ! -e "$DST/.zenv" ]]; then
  cat >"$DST/.zenv" <<'EOF'
# Local env (not tracked). Sourced with set -a from .zshrc.
# Add machine-specific exports here.
EOF
  echo "created $DST/.zenv placeholder"
fi

if [[ $SKIP_PACKAGES -eq 0 && -f "$DST/bootstrap.sh" ]]; then
  bootstrap_args=()
  [[ $SKIP_APPS -eq 1 ]] && bootstrap_args+=(--skip-apps)
  # shellcheck disable=SC1091
  bash "$DST/bootstrap.sh" "${bootstrap_args[@]}"
fi

echo "install finished"
