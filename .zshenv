. "$HOME/.cargo/env"

# Zed (and other GUI apps) spawn a login, non-interactive zsh that never
# reads ~/.zshrc. Keep user-local tools on PATH here so `shellcheck`,
# `shfmt`, and wrappers in ~/.local/bin resolve without absolute paths.
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac
