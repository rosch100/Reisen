#!/usr/bin/env bash
# Einmalig Gmail-OAuth Refresh-Token holen. Secrets niemals loggen.
set -euo pipefail
set +x

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

exec python3 "$ROOT/Scripts/authorize-gmail-feedback-oauth.py" "$@"
