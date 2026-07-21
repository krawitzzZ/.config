add-ssh() {
  ssh-add ~/.ssh/*
}

killport() {
  local process_id=$(lsof -t -i:"$1")

  if [ -n "$process_id" ]; then
    kill -9 "$process_id"
  fi
}

dockerStop() {
  docker stop $(docker ps -q)
  yes | docker container prune --force
}
