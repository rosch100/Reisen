#!/usr/bin/env bash
# Idempotenter Install-Hook für Produkt-/App-Repos (Cloud Agent environment.json → install).
# Klont/aktualisiert Altanis/cursor und verdrahtet ~/.cursor + /.cursor.
#
# Voraussetzung: Netz zu git.altanis.de. Auth:
#   Cursor Secret ALTANIS_ENTWICKLUNG_FORGEJO_TOKEN (Forgejo PAT, repo-read)
#   optional Fallback: CURSOR_SSOT_GIT_TOKEN
set -euo pipefail

REMOTE="${CURSOR_SSOT_REMOTE:-https://git.altanis.de/Altanis/cursor.git}"
CLONE="${CURSOR_SSOT_CLONE:-$HOME/Entwicklung/Altanis/cursor}"
BRANCH="${CURSOR_SSOT_BRANCH:-main}"

CRED_SCRIPT=""
GIT_CONFIG_ARGS=()
CLEAN_REMOTE=""

cleanup() {
  if [ -n "${CRED_SCRIPT}" ] && [ -f "${CRED_SCRIPT}" ]; then
    rm -f "${CRED_SCRIPT}"
    CRED_SCRIPT=""
  fi
  unset CURSOR_SSOT_GIT_OAUTH_TOKEN 2>/dev/null || true
  if [ -n "${CLEAN_REMOTE}" ] && [ -d "${CLONE}/.git" ]; then
    git -C "${CLONE}" remote set-url origin "${CLEAN_REMOTE}" 2>/dev/null || true
  fi
}

forgejo_token() {
  if [ -n "${ALTANIS_ENTWICKLUNG_FORGEJO_TOKEN:-}" ]; then
    printf '%s' "${ALTANIS_ENTWICKLUNG_FORGEJO_TOKEN}"
  elif [ -n "${CURSOR_SSOT_GIT_TOKEN:-}" ]; then
    printf '%s' "${CURSOR_SSOT_GIT_TOKEN}"
  fi
}

strip_auth_from_https() {
  local rest="${1#https://}"
  rest="${rest#*@}"
  printf 'https://%s' "${rest}"
}

validate_remote() {
  case "${REMOTE}" in
    https://*) ;;
    *)
      echo "Unsupported CURSOR_SSOT_REMOTE (only https://): ${REMOTE}" >&2
      exit 1
      ;;
  esac
}

configure_ephemeral_auth() {
  local token
  token="$(forgejo_token)"
  [ -n "${token}" ] || return 0

  export CURSOR_SSOT_GIT_OAUTH_TOKEN="${token}"
  CRED_SCRIPT="$(mktemp -t cursor-ssot-git-cred.XXXXXX)"
  chmod 700 "${CRED_SCRIPT}"
  cat > "${CRED_SCRIPT}" <<'SCRIPT'
#!/usr/bin/env bash
case "$1" in
get)
  printf '%s\n' 'username=oauth2'
  printf '%s\n' "password=${CURSOR_SSOT_GIT_OAUTH_TOKEN}"
  ;;
store|erase) ;;
esac
SCRIPT

  GIT_CONFIG_ARGS=(-c "credential.helper=!${CRED_SCRIPT}")
}

git_ssot() {
  git "${GIT_CONFIG_ARGS[@]}" "$@"
}

self_test() {
  local got cred_out saved_remote saved_clean
  saved_remote="${REMOTE}"
  saved_clean="${CLEAN_REMOTE}"

  got="$(strip_auth_from_https 'https://oauth2:secret@git.altanis.de/Altanis/cursor.git')"
  if [ "${got}" != 'https://git.altanis.de/Altanis/cursor.git' ]; then
    echo "strip_auth_from_https failed: ${got}" >&2
    return 1
  fi

  REMOTE='https://git.altanis.de/Altanis/cursor.git'
  validate_remote

  if ( REMOTE='ftp://bad'; validate_remote ) 2>/dev/null; then
    echo 'validate_remote should reject non-https' >&2
    return 1
  fi

  ALTANIS_ENTWICKLUNG_FORGEJO_TOKEN='token"with\\quotes'
  configure_ephemeral_auth
  cred_out="$("${CRED_SCRIPT}" get)"
  if ! printf '%s\n' "${cred_out}" | grep -qx 'username=oauth2'; then
    echo 'credential helper missing username=oauth2' >&2
    return 1
  fi
  if [ "$(printf '%s\n' "${cred_out}" | sed -n '2p')" != "password=$(forgejo_token)" ]; then
    echo 'credential helper env read failed' >&2
    return 1
  fi
  if grep -q 'token"with' "${CRED_SCRIPT}" 2>/dev/null; then
    echo 'token must not be embedded in credential script' >&2
    return 1
  fi
  rm -f "${CRED_SCRIPT}"
  CRED_SCRIPT=""
  unset ALTANIS_ENTWICKLUNG_FORGEJO_TOKEN CURSOR_SSOT_GIT_OAUTH_TOKEN

  REMOTE="${saved_remote}"
  CLEAN_REMOTE="${saved_clean}"
  echo 'install-user-ssot self-test OK'
}

if [ "${1:-}" = '--self-test' ]; then
  self_test
  exit 0
fi

validate_remote
CLEAN_REMOTE="$(strip_auth_from_https "${REMOTE}")"
trap cleanup EXIT

configure_ephemeral_auth
mkdir -p "$(dirname "${CLONE}")"

if [ ! -d "${CLONE}/.git" ]; then
  git_ssot clone --branch "${BRANCH}" "${CLEAN_REMOTE}" "${CLONE}"
else
  git -C "${CLONE}" remote set-url origin "${CLEAN_REMOTE}"
  git_ssot -C "${CLONE}" fetch origin --prune
  git_ssot -C "${CLONE}" checkout -B "${BRANCH}" "origin/${BRANCH}"
  git_ssot -C "${CLONE}" reset --hard "origin/${BRANCH}"
  git_ssot -C "${CLONE}" clean -fd
fi

git -C "${CLONE}" remote set-url origin "${CLEAN_REMOTE}"

# Immer das Skript aus dem Archiv (nicht eine veraltete Repo-Kopie).
exec bash "${CLONE}/Scripts/sync-cloud.sh"
