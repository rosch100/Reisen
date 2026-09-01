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

forgejo_token() {
  if [ -n "${ALTANIS_ENTWICKLUNG_FORGEJO_TOKEN:-}" ]; then
    printf '%s' "${ALTANIS_ENTWICKLUNG_FORGEJO_TOKEN}"
  elif [ -n "${CURSOR_SSOT_GIT_TOKEN:-}" ]; then
    printf '%s' "${CURSOR_SSOT_GIT_TOKEN}"
  fi
}

auth_remote() {
  local token
  token="$(forgejo_token)"
  if [ -n "${token}" ]; then
    printf 'https://oauth2:%s@git.altanis.de/Altanis/cursor.git' "${token}"
  else
    printf '%s' "${REMOTE}"
  fi
}

mkdir -p "$(dirname "${CLONE}")"
FETCH_REMOTE="$(auth_remote)"

if [ ! -d "${CLONE}/.git" ]; then
  git clone "${FETCH_REMOTE}" "${CLONE}"
else
  git -C "${CLONE}" remote set-url origin "${FETCH_REMOTE}"
  git -C "${CLONE}" fetch origin --prune
  git -C "${CLONE}" checkout -B "${BRANCH}" "origin/${BRANCH}"
  git -C "${CLONE}" reset --hard "origin/${BRANCH}"
  git -C "${CLONE}" clean -fd
fi

if [ -n "$(forgejo_token)" ]; then
  git -C "${CLONE}" remote set-url origin "${REMOTE}"
fi

# Immer das Skript aus dem Archiv (nicht eine veraltete Repo-Kopie).
exec bash "${CLONE}/Scripts/sync-cloud.sh"
