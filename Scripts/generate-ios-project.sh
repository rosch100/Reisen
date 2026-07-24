#!/usr/bin/env bash
# Erzeugt das iOS Xcode-Projekt aus project.yml (XcodeGen SSOT).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Fehler: xcodegen nicht gefunden. Installieren mit: brew install xcodegen" >&2
  exit 1
fi

if [[ ! -f "$ROOT/project.yml" ]]; then
  echo "Fehler: project.yml fehlt im Repo-Root." >&2
  exit 1
fi

xcodegen generate --spec "$ROOT/project.yml" --project "$ROOT"

if [[ ! -d "$ROOT/Reisen.xcodeproj" ]]; then
  echo "Fehler: Reisen.xcodeproj wurde nicht erzeugt." >&2
  exit 1
fi

echo "OK: $ROOT/Reisen.xcodeproj"
