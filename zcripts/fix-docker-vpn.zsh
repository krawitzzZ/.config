fix_docker_vpn() {
  local comment=docker-vpn-snat
  local vpn_ip to listing

  vpn_ip=$(ip -4 route show default | awk '/scope link/ {
    for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit }
  }')

  listing=$(sudo iptables -t nat -S POSTROUTING) || return 1
  to=$(print -r -- "$listing" | awk -v c="$comment" 'index($0, c) { print $NF; exit }')
  while [[ -n "$to" ]]; do
    sudo iptables -t nat -D POSTROUTING \
      -s 172.16.0.0/12 ! -o docker0 \
      -m comment --comment "$comment" \
      -j SNAT --to-source "$to" || break
    listing=$(sudo iptables -t nat -S POSTROUTING) || return 1
    to=$(print -r -- "$listing" | awk -v c="$comment" 'index($0, c) { print $NF; exit }')
  done

  if [[ -z "$vpn_ip" ]]; then
    echo "VPN is down; Docker SNAT removed"
    return 0
  fi

  sudo iptables -t nat -I POSTROUTING 1 \
    -s 172.16.0.0/12 ! -o docker0 \
    -m comment --comment "$comment" \
    -j SNAT --to-source "$vpn_ip"
  echo "Docker SNAT -> $vpn_ip"
}
