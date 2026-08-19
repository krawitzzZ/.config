nclean() {
    emulate -L zsh
    setopt null_glob
    rm -rf package-lock.json node_modules dist lib ./**/package-lock.json ./**/node_modules ./**/dist ./**/lib 2>/dev/null
}

nreinstall() {
    nclean
    npm install --force --verbose
}
