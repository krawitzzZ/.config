# pnpm (standalone), then Node.js LTS with the npm that ships beside it.
export PNPM_HOME="${PNPM_HOME:-$HOME/.local/pnpm}"
mkdir -p "$PNPM_HOME"
export PATH="$PNPM_HOME:$PNPM_HOME/bin:$HOME/.local/node/bin:$PATH"

if ! have pnpm; then
  curl -fsSL https://get.pnpm.io/install.sh |
    env PNPM_HOME="$PNPM_HOME" SHELL=/bin/bash ENV="$HOME/.bashrc" bash -
  export PATH="$PNPM_HOME:$PNPM_HOME/bin:$PATH"
fi

install_node_lts() {
  local ver arch tarball tmp dest
  ver=$(curl -fsSL https://nodejs.org/dist/index.json | python3 -c '
import json, sys
for rel in json.load(sys.stdin):
    if rel.get("lts"):
        print(rel["version"])
        break
')
  [[ -n "$ver" ]] || {
    echo "error: could not resolve Node.js LTS version" >&2
    exit 1
  }
  case "$(dpkg_arch)" in
    amd64) arch=x64 ;;
    arm64) arch=arm64 ;;
    *)
      echo "error: no Node.js LTS tarball for $(dpkg_arch)" >&2
      exit 1
      ;;
  esac
  dest=$HOME/.local/node
  if [[ -x "$dest/bin/node" ]] && "$dest/bin/node" -v 2>/dev/null | grep -Fq "$ver"; then
    return 0
  fi
  tarball="node-${ver}-linux-${arch}.tar.xz"
  tmp=$(mktemp -d)
  curl -fsSL "https://nodejs.org/dist/${ver}/${tarball}" -o "$tmp/$tarball"
  rm -rf "$dest"
  mkdir -p "$dest"
  tar -xJf "$tmp/$tarball" -C "$dest" --strip-components=1
  rm -rf "$tmp"
}

install_node_lts
export PATH="$HOME/.local/node/bin:$PATH"

if ! have node || ! have npm; then
  echo "error: Node.js LTS install did not put node/npm on PATH" >&2
  exit 1
fi
