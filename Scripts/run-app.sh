#!/usr/bin/env bash
# Baut und startet Reisen.app (nicht: rohes swift run).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "Baue Reisen.app..." >&2
APP="$("$ROOT/Scripts/build-app.sh")"

pkill -x Reisen 2>/dev/null || true
sleep 0.3

# Launch Services trifft bei gleicher Bundle-ID oft /Applications (ältere Kopie).
# `-n` + Pfad startet genau dieses Bundle; kein `open -a` / Bundle-ID-Activate.
open -n "$APP"
echo "Gestartet: $APP" >&2
