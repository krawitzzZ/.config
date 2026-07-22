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
