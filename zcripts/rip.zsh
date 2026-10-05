rip() {
  local input="$1"
  local host="${input#*://}" # strip scheme (http://, https://, ...) if present
  host="${host%%/*}"         # strip path
  host="${host##*@}"         # strip userinfo (user:pass@)
  host="${host%%:*}"         # strip port

  [[ "$host" =~ '^[0-9]{1,3}$' ]] && host="10.22.200.$host"

  if [[ -z "$host" || ! "$host" =~ '^([0-9]{1,3}(\.[0-9]{1,3}){3}|([a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?\.)*[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)$' ]]; then
    echo "could not extract an IP address or FQDN from '$1'" >&2
    return 1
  fi

  export ROBOT_IP="$host"
  export ROBOT_PROXY="$host"

  echo "ROBOT_IP:    $ROBOT_IP"
  echo "ROBOT_PROXY: $ROBOT_PROXY"

  if ! ping -c 1 -W 1 "$ROBOT_IP" >/dev/null 2>&1; then
    print -r -- $'\e[38;5;208m'"WARN: $ROBOT_IP is currently not reachable"$'\e[0m' >&2
  fi
}
