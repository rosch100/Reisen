#!/usr/bin/env bash
# Baut und startet Reisen.app (nicht: rohes swift run).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

logging_enabled=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --logging)
      logging_enabled=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [--logging]" >&2
      exit 0
      ;;
    *)
      echo "Fehler: Unbekanntes Argument: $1" >&2
      echo "Usage: $0 [--logging]" >&2
      exit 2
      ;;
  esac
done

echo "Baue Reisen.app..." >&2
# build-app.sh beendet bereits eine laufende .build/Reisen.app-Instanz vor rm -rf.
APP="$("$ROOT/Scripts/build-app.sh")"

# Launch Services trifft bei gleicher Bundle-ID oft /Applications (ältere Kopie).
# `-n` + Pfad startet genau dieses Bundle; kein `open -a` / Bundle-ID-Activate.
open_args=(-n "$APP")
if [[ "$logging_enabled" == true ]]; then
  open_args+=(--args -ReisenDiagnosticsDebug)
fi
open "${open_args[@]}"
echo "Gestartet: $APP" >&2
