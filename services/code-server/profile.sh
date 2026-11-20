# Login shells in code-server's terminal: tools installed with npm -g,
# pip --user or pipx live in ~/.local on the Railway volume.
case ":${PATH}:" in
  *:"${HOME}/.local/bin":*) ;;
  *) PATH="${HOME}/.local/bin:${PATH}" ;;
esac
export PATH
export NPM_CONFIG_PREFIX="${HOME}/.local"
