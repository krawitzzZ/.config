add-ssh() {
  ssh-add ~/.ssh/*
}

killport() {
  local -a pids=(${(f)"$(lsof -t -i:"$1")"})

  if (( ${#pids} )); then
    kill -9 $pids
  fi
}

dockerStop() {
  docker stop $(docker ps -q)
  yes | docker container prune --force
}
