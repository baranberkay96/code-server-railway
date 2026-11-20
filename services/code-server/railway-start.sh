#!/usr/bin/env bash
# railway-start: prepares the Railway volume and starts code-server as "coder".
#
#  1. Checks PORT and PASSWORD. No variable fails the deploy: an invalid port
#     falls back to 8080, and without a usable password (8-256 bytes, one
#     line) code-server gets a random password nobody knows, so the editor
#     is locked, never open. The log says how to fix it.
#  2. Makes the home directory /home/coder (the volume) belong to coder and
#     seeds the shell files and editor settings on a fresh volume.
#  3. Optionally clones GIT_REPO into ~/project on the first start.
#  4. Runs the user's ~/entrypoint.d scripts (as coder), like coder's image.
#  5. Starts code-server as coder with password login. code-server removes
#     PASSWORD from its environment, so terminals and extensions cannot read it.
#  6. In the background: reinstalls APT_PACKAGES and installs EXTENSIONS.
set -Eeuo pipefail

readonly CODER_USER="coder"
readonly CODER_HOME="/home/coder"
readonly PROJECT_DIR="${CODER_HOME}/project"
readonly SETTINGS_SOURCE="/usr/local/share/railway-code-server/settings.json"
readonly SETTINGS_FILE="${CODER_HOME}/.local/share/code-server/User/settings.json"
readonly STATE_DIR="${CODER_HOME}/.local/state/railway"
readonly DEFAULT_PORT=8080
readonly MIN_PASSWORD_LENGTH=8
readonly RECOMMENDED_PASSWORD_LENGTH=12
readonly MAX_PASSWORD_BYTES=256
readonly GIT_CLONE_TIMEOUT=300
readonly EXTENSION_PATTERN='^[A-Za-z0-9][A-Za-z0-9-]*\.[A-Za-z0-9][A-Za-z0-9._-]*(@[0-9][0-9A-Za-z.+-]*)?$'

log() { printf '[railway-start] %s\n' "$*" >&2; }

is_port() {
  [[ "$1" =~ ^[1-9][0-9]{0,4}$ ]] && (( $1 <= 65535 ))
}

as_coder() {
  setpriv --reuid="$CODER_USER" --regid="$CODER_USER" --init-groups \
    env HOME="$CODER_HOME" USER="$CODER_USER" LOGNAME="$CODER_USER" "$@"
}

lock_login() {
  log "WARNING: $* code-server starts with a random password nobody knows, so the editor stays locked. Set PASSWORD (12+ characters) in the service Variables and redeploy."
  PASSWORD="$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')"
}

validate_settings() {
  PORT="${PORT:-$DEFAULT_PORT}"
  if ! is_port "$PORT"; then
    log "WARNING: PORT must be a number between 1 and 65535 (got '${PORT}'). Using ${DEFAULT_PORT}."
    PORT="$DEFAULT_PORT"
  fi
  export PORT

  # A login cannot be switched off from the deploy form: code-server always
  # runs with --auth password. HASHED_PASSWORD is honoured if set.
  if [[ -n "${HASHED_PASSWORD:-}" ]]; then
    log "Using HASHED_PASSWORD for the login."
    unset PASSWORD
    return 0
  fi
  PASSWORD="${PASSWORD:-}"
  if (( ${#PASSWORD} < MIN_PASSWORD_LENGTH )); then
    lock_login "PASSWORD is empty or shorter than ${MIN_PASSWORD_LENGTH} characters."
  elif [[ "$PASSWORD" == *$'\n'* ]]; then
    lock_login "PASSWORD must be a single line."
  elif (( $(printf '%s' "$PASSWORD" | wc -c) > MAX_PASSWORD_BYTES )); then
    lock_login "PASSWORD is longer than ${MAX_PASSWORD_BYTES} bytes."
  elif (( ${#PASSWORD} < RECOMMENDED_PASSWORD_LENGTH )); then
    log "WARNING: PASSWORD has fewer than ${RECOMMENDED_PASSWORD_LENGTH} characters. The editor is public and its terminal has sudo; use a longer password."
  fi
  export PASSWORD
}

# Railway mounts a new volume owned by root. Fix the owner once (the top
# directory tells), and seed the shell files a fresh home directory needs.
prepare_home() {
  if command -v mountpoint > /dev/null 2>&1 && ! mountpoint -q "$CODER_HOME"; then
    log "WARNING: ${CODER_HOME} is not a mounted volume. Projects, extensions and settings are lost on every redeploy."
  fi
  install -d -m 0755 "$CODER_HOME"
  if [[ "$(stat -c %U "$CODER_HOME")" != "$CODER_USER" ]]; then
    log "Giving ${CODER_HOME} to ${CODER_USER} (first start on this volume)."
    chown -R "${CODER_USER}:${CODER_USER}" "$CODER_HOME"
  fi
  local file
  for file in .bashrc .profile .bash_logout; do
    if [[ ! -e "${CODER_HOME}/${file}" && -f "/etc/skel/${file}" ]]; then
      as_coder cp "/etc/skel/${file}" "${CODER_HOME}/${file}"
    fi
  done
  as_coder mkdir -p "$PROJECT_DIR" "$STATE_DIR" "$(dirname "$SETTINGS_FILE")" "${CODER_HOME}/.local/bin"
  if [[ ! -e "$SETTINGS_FILE" ]]; then
    as_coder cp "$SETTINGS_SOURCE" "$SETTINGS_FILE"
  fi
}

# Clones GIT_REPO once, into an empty ~/project. A failed clone only warns.
clone_repository() {
  local repo="${GIT_REPO:-}"
  [[ -n "$repo" ]] || return 0
  if [[ -n "$(ls -A "$PROJECT_DIR" 2> /dev/null)" ]]; then
    return 0
  fi
  if [[ ! "$repo" =~ ^(https://|git@|ssh://)[^[:space:]]+$ ]]; then
    log "WARNING: GIT_REPO must start with https://, ssh:// or git@ (got '${repo:0:80}'). Not cloned."
    return 0
  fi
  # Never log credentials that may be part of the URL.
  log "Cloning $(printf '%s' "${repo%%\?*}" | sed -E 's#://[^@/]*@#://#') into ${PROJECT_DIR} ..."
  if as_coder env GIT_TERMINAL_PROMPT=0 timeout "$GIT_CLONE_TIMEOUT" \
      git clone --quiet -- "$repo" "$PROJECT_DIR" 2>&1 | sed -E 's#://[^@/[:space:]]*@#://#g; s/^/[git] /' >&2 \
      && [[ -d "${PROJECT_DIR}/.git" ]]; then
    log "Repository cloned."
  else
    log "WARNING: git clone failed (private repository, wrong URL or network). Clone it later from the terminal."
    as_coder mkdir -p "$PROJECT_DIR"
  fi
}

# Same hook as coder's own image: executable files in ~/entrypoint.d run
# before code-server starts, as coder. A failing script only warns.
run_entrypoint_scripts() {
  local dir="${CODER_HOME}/entrypoint.d" script
  [[ -d "$dir" ]] || return 0
  while IFS= read -r -d '' script; do
    log "Running ${script} ..."
    as_coder timeout 300 "$script" || log "WARNING: ${script} exited with status $?."
  done < <(find "$dir" -maxdepth 1 -type f -perm -u+x -print0 | sort -z)
}

install_extensions() {
  local -a ids=()
  local id
  read -r -a ids <<< "${EXTENSIONS//,/ }"
  for id in "${ids[@]}"; do
    if [[ ! "$id" =~ $EXTENSION_PATTERN ]]; then
      log "Skipping invalid extension id '${id:0:80}'."
      continue
    fi
    if as_coder code-server --install-extension "$id" > /dev/null 2>&1; then
      log "Extension ${id} installed."
    else
      log "WARNING: could not install extension ${id} (Open VSX has no such id?)."
    fi
  done
}

background_jobs() {
  nice -n 10 /usr/local/bin/railway-pkg-restore || true
  if [[ -n "${EXTENSIONS:-}" ]]; then
    install_extensions
  fi
}

main() {
  validate_settings
  prepare_home
  clone_repository
  run_entrypoint_scripts
  # Detached (double fork), so the finished job is reaped by init, not left to code-server.
  ( background_jobs & )

  local url="the service's public domain"
  [[ -z "${RAILWAY_PUBLIC_DOMAIN:-}" ]] || url="https://${RAILWAY_PUBLIC_DOMAIN}/"
  log "code-server $(node -p "require('/usr/lib/code-server/package.json').version" 2> /dev/null || echo unknown), Node.js $(node --version), $(python3 --version 2>&1)."
  log "Starting code-server on port ${PORT}. Sign in at ${url} with the PASSWORD from the service Variables."
  cd "$PROJECT_DIR"
  exec setpriv --reuid="$CODER_USER" --regid="$CODER_USER" --init-groups \
    env HOME="$CODER_HOME" USER="$CODER_USER" LOGNAME="$CODER_USER" SHELL=/bin/bash \
    code-server --bind-addr "0.0.0.0:${PORT}" --auth password \
      --disable-telemetry --disable-update-check "$PROJECT_DIR"
}

main "$@"
