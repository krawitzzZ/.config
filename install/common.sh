# Shared helpers for bootstrap.sh. Sourced, not executed.
have() { command -v "$1" >/dev/null 2>&1; }

run_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  elif have sudo; then
    sudo "$@"
  else
    echo "error: need root for: $*" >&2
    exit 1
  fi
}

github_latest_tag() {
  local url
  url=$(curl -fsSL -o /dev/null -w '%{url_effective}' "$1")
  url=${url%/}
  printf '%s\n' "${url##*/}"
}

dpkg_arch() {
  dpkg --print-architecture
}
