nclean() {
    emulate -L zsh
    setopt null_glob
    rm -rf package-lock.json node_modules ./**/node_modules ./**/package-lock.json 2>/dev/null
}

nreinstall() {
    nclean
    npm install --force --verbose
}
