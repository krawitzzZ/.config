swagit() {
  if [ "$1" != "" ]
  then
    docker run --rm -p 8080:8080 -e SWAGGER_JSON=/foo/${1} -v "$(pwd):/foo" swaggerapi/swagger-ui
  else
    docker run --rm -p 8080:8080 -e SWAGGER_JSON=/foo/swagger.yaml -v "$(pwd):/foo" swaggerapi/swagger-ui
  fi
}

swagedit() {
  if [ "$1" != "" ]
  then
    docker run --rm -p 8080:8080 -e SWAGGER_FILE=/foo/${1} -v "$(pwd):/foo" swaggerapi/swagger-editor
  else
    docker run --rm -p 8080:8080 swaggerapi/swagger-editor
  fi
}

weather() {
  if [ "$1" != "" ]
  then
    curl wttr.in/"$1"
  else
    curl wttr.in
  fi
}

cleanupCursor() {
    rm -rf ~/.config/cursor/chats/* ~/.config/cursor/acp-sessions/* ~/.cursor/projects/* || true
    rm -rf ~/.local/share/zed/threads/threads.db || true
    rm -rf ~/.local/share/zed/db/0-stable/db.sqlite* || true
}

whatOnPort() {
  local port="$1"

  if [ -z "$port" ]; then
    echo "usage: whatOnPort <port>" >&2
    return 2
  fi

  if ! [[ "$port" =~ '^[0-9]+$' ]] || (( port < 1 || port > 65535 )); then
    echo "error: '$port' is not a valid TCP port (expected 1-65535)" >&2
    return 2
  fi

  if ! command -v ss >/dev/null 2>&1; then
    echo "error: 'ss' (iproute2) is not available" >&2
    return 2
  fi

  local sockets
  sockets=$(ss -H -tlnp "sport = :$port" 2>/dev/null)

  if [ -z "$sockets" ]; then
    echo "nothing is listening on TCP port $port"
    return 1
  fi

  local -a pids
  pids=(${(f)"$(echo "$sockets" | grep -oE 'pid=[0-9]+' | cut -d= -f2 | sort -u)"})

  if [ ${#pids[@]} -eq 0 ]; then
    echo "TCP port $port is in use, but process info is hidden (re-run with sudo):"
    echo "$sockets"
    return 0
  fi

  local pid
  for pid in "${pids[@]}"; do
    if ! ps -p "$pid" >/dev/null 2>&1; then
      echo "pid $pid: process gone or not accessible (try sudo)"
      continue
    fi

    echo "process:  $(ps -o comm= -p "$pid")"
    echo "  pid:      $pid"
    echo "  ppid:     $(ps -o ppid= -p "$pid" | tr -d ' ')"
    echo "  user:     $(ps -o user= -p "$pid")"
    echo "  started:  $(ps -o lstart= -p "$pid")"
    echo "  cpu/mem:  $(ps -o %cpu=,%mem= -p "$pid" | tr -s ' ')"
    echo "  rss:      $(ps -o rss= -p "$pid" | tr -d ' ') KB"
    echo "  cmd:      $(ps -o args= -p "$pid")"
    echo "  binds:"
    echo "$sockets" | grep "pid=$pid," | awk '{print "    " $1 " " $4}'
    echo
  done
}
