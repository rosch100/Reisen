#!/usr/bin/env bash
# Produkt-SwiftPM-Build für CodeQL/CI: eine Architektur, ohne Test-Targets.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ARCH="$(uname -m)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --arch)
      ARCH="${2:-}"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 [--arch arm64|x86_64]" >&2
      exit 0
      ;;
    *)
      echo "Fehler: Unbekanntes Argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$ARCH" ]]; then
  echo "Fehler: --arch darf nicht leer sein." >&2
  exit 2
fi

# Kein --build-tests: CodeQL braucht nur getracte Product-Sources.
swift build --arch "$ARCH"
