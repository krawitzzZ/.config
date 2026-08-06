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

reviewers() {
    echo "@simon.gabl @stefan.loibl @carlo.cagnetta @james.browne @noyan.sahin @moritz.martens @david.kraus @imdad.hussain @olha.todorashko @frank.dedden @michaela.frodlova @shu.lo"
}
