#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

usage() {
  echo "Usage: $0 --app-path /abs/path/to/Reisen.app" >&2
  echo "       $0 --dmg-path /abs/path/to/Reisen.dmg" >&2
}

APP_PATH=""
DMG_PATH=""
ZIP_PATH=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-path)
      APP_PATH="${2:-}"
      shift 2
      ;;
    --dmg-path)
      DMG_PATH="${2:-}"
      shift 2
      ;;
    --zip-path)
      ZIP_PATH="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Fehler: Unbekanntes Argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$APP_PATH" && -z "$DMG_PATH" ]]; then
  echo "Fehler: --app-path oder --dmg-path ist erforderlich." >&2
  usage
  exit 2
fi

if [[ -n "$APP_PATH" && ( ! -d "$APP_PATH" || "$APP_PATH" != *.app ) ]]; then
  echo "Fehler: APP_PATH ist kein .app Bundle: $APP_PATH" >&2
  exit 2
fi

if [[ -n "$DMG_PATH" && ( ! -f "$DMG_PATH" || "$DMG_PATH" != *.dmg ) ]]; then
  echo "Fehler: DMG_PATH ist keine .dmg Datei: $DMG_PATH" >&2
  exit 2
fi

require_env() {
  local key="$1"
  if [[ -z "${!key:-}" ]]; then
    echo "Fehler: Environment-Variable fehlt: $key" >&2
    exit 1
  fi
}

require_env "APPLE_TEAM_ID"
require_env "APPLE_DEVELOPER_ID_P12_BASE64"
require_env "APPLE_DEVELOPER_ID_P12_PASSWORD"

require_env "APP_STORE_CONNECT_API_KEY_BASE64"
require_env "APP_STORE_CONNECT_API_KEY_KEY_ID"
require_env "APP_STORE_CONNECT_API_KEY_ISSUER"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Fehler: Command nicht gefunden: $1" >&2
    exit 1
  fi
}

require_cmd security
require_cmd codesign
require_cmd xcrun

WORK_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$WORK_DIR" >/dev/null 2>&1 || true
}
trap cleanup EXIT

P12_PATH="$WORK_DIR/developer-id.p12"
P8_PATH="$WORK_DIR/AuthKey.p8"

printf '%s' "$APPLE_DEVELOPER_ID_P12_BASE64" | base64 --decode >"$P12_PATH"
printf '%s' "$APP_STORE_CONNECT_API_KEY_BASE64" | base64 --decode >"$P8_PATH"

KC_NAME="reisen-ci-keychain"
KC_PASS="$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24)"

echo "Erzeuge Keychain: $KC_NAME" >&2
security create-keychain -p "$KC_PASS" "$KC_NAME" >/dev/null
security unlock-keychain -p "$KC_PASS" "$KC_NAME" >/dev/null

echo "Importiere Developer ID Zertifikat..." >&2
security import "$P12_PATH" -k "$KC_NAME" -P "$APPLE_DEVELOPER_ID_P12_PASSWORD" \
  -T /usr/bin/codesign -T /usr/bin/security >/dev/null

# Partition list, damit codesign ohne Prompt zugreifen kann.
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KC_PASS" "$KC_NAME" >/dev/null 2>&1 || true

security list-keychains -d user -s "$KC_NAME" >/dev/null

IDENTITY="$(
  security find-identity -p codesigning -v "$KC_NAME" |
    awk -F'"' '/Developer ID Application/ {print $2; exit}'
)"

if [[ -z "$IDENTITY" ]]; then
  echo "Fehler: Developer ID Application Identity nicht gefunden (Keychain: $KC_NAME)." >&2
  exit 1
fi

notarize_submit() {
  local artifact_path="$1"
  echo "Notarize via notarytool (wait...): $artifact_path" >&2
  xcrun notarytool submit "$artifact_path" \
    --key "$P8_PATH" \
    --key-id "$APP_STORE_CONNECT_API_KEY_KEY_ID" \
    --issuer "$APP_STORE_CONNECT_API_KEY_ISSUER" \
    --wait
}

if [[ -n "$APP_PATH" ]]; then
  echo "Codesign .app (Developer ID)..." >&2
  codesign --force --sign "$IDENTITY" --timestamp --options runtime "$APP_PATH" >/dev/null

  # Deep sign für nested resource bundles (sichert Notary-Checks ab).
  codesign --force --sign "$IDENTITY" --timestamp --options runtime --deep "$APP_PATH" >/dev/null

  if [[ -z "$ZIP_PATH" ]]; then
    ZIP_PATH="$ROOT/.build/notarize/$(basename "$APP_PATH" .app).zip"
  fi

  mkdir -p "$(dirname "$ZIP_PATH")"

  echo "Erzeuge ZIP: $ZIP_PATH" >&2
  ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

  notarize_submit "$ZIP_PATH"

  echo "Staple .app (nach Notarization)..." >&2
  xcrun stapler staple -v "$APP_PATH"

  echo "Fertig: $APP_PATH" >&2
  printf '%s\n' "$APP_PATH"
fi

if [[ -n "$DMG_PATH" ]]; then
  echo "Codesign .dmg (Developer ID)..." >&2
  codesign --force --sign "$IDENTITY" --timestamp "$DMG_PATH" >/dev/null

  notarize_submit "$DMG_PATH"

  echo "Staple .dmg (nach Notarization)..." >&2
  xcrun stapler staple -v "$DMG_PATH"

  echo "Fertig: $DMG_PATH" >&2
  printf '%s\n' "$DMG_PATH"
fi
