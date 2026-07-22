#!/usr/bin/env bash
# Baut und startet Reisen.app (nicht: rohes swift run).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "Baue Reisen.app..." >&2
APP="$("$ROOT/Scripts/build-app.sh")"

pkill -x Reisen 2>/dev/null || true
sleep 0.3

# open -a aktiviert zuverlässiger als open <path> (sonst oft hinter Cursor).
open -a "$APP"
sleep 0.4
osascript -e 'tell application "Reisen" to activate' >/dev/null 2>&1 || true
echo "Gestartet: $APP" >&2
