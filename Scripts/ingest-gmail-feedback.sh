#!/usr/bin/env bash
# Gmail API (OAuth) → GitHub Issues. Secrets niemals loggen.
set -euo pipefail
set +x

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

exec python3 "$ROOT/Scripts/ingest-gmail-feedback.py" "$@"
