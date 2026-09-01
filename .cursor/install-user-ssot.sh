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

cleanup() {
  if [ -n "${CRED_SCRIPT}" ] && [ -f "${CRED_SCRIPT}" ]; then
    rm -f "${CRED_SCRIPT}"
    CRED_SCRIPT=""
  fi
  if [ -d "${CLONE}/.git" ]; then
    git -C "${CLONE}" remote set-url origin "${CLEAN_REMOTE}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

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

  CRED_SCRIPT="$(mktemp -t cursor-ssot-git-cred.XXXXXX)"
  chmod 700 "${CRED_SCRIPT}"
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' 'case "$1" in'
    printf '%s\n' 'get)'
    printf '%s\n' '  printf "%s\n" "username=oauth2"'
    printf '  printf "%%s\\n" "password=%s"\n' "${token}"
    printf '%s\n' '  ;;'
    printf '%s\n' 'store|erase) ;;'
    printf '%s\n' 'esac'
  } > "${CRED_SCRIPT}"

  GIT_CONFIG_ARGS=(-c "credential.helper=!${CRED_SCRIPT}")
}

git_ssot() {
  git "${GIT_CONFIG_ARGS[@]}" "$@"
}

validate_remote
CLEAN_REMOTE="$(strip_auth_from_https "${REMOTE}")"
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
