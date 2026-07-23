nrr() {
    emulate -L zsh
    # null_glob: drop ./**/node_modules from the args when nothing matches,
    # instead of erroring on "no matches found".
    setopt local_options null_glob

    # Cleanup must never fail the function; -f ignores missing paths.
    rm -rf package-lock.json node_modules ./**/node_modules ./**/package-lock.json 2>/dev/null

    # Only this determines the function's exit status.
    npm install --force --prefer-online
}
