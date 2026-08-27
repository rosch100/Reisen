#!/usr/bin/env bash
# Erzeugt ein App-Store-Archive und exportiert ein IPA (ohne eingebettetes GitHub-PAT).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SCHEME="ReiseniOS"
PROJECT="$ROOT/Reisen.xcodeproj"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT/.build/ReiseniOS.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$ROOT/.build/ReiseniOS-ipa}"
EXPORT_OPTIONS="${EXPORT_OPTIONS:-$ROOT/Scripts/ios-export-appstore.plist}"

export REISEN_GITHUB_ISSUE_TOKEN_EMPTY=true
unset REISEN_EMBED_GITHUB_ISSUE_TOKEN

bash "$ROOT/Scripts/generate-ios-project.sh"

if [[ ! -f "$EXPORT_OPTIONS" ]]; then
  echo "Fehler: ExportOptions fehlt: $EXPORT_OPTIONS" >&2
  exit 1
fi

mkdir -p "$(dirname "$ARCHIVE_PATH")"
mkdir -p "$EXPORT_PATH"

echo "Archive (Release, generic iOS) …" >&2
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE_PATH" \
  archive \
  -allowProvisioningUpdates

echo "Export IPA (app-store) …" >&2
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -allowProvisioningUpdates

IPA="$(find "$EXPORT_PATH" -maxdepth 1 -name '*.ipa' -print -quit)"
if [[ -z "$IPA" ]]; then
  echo "Fehler: Kein IPA unter $EXPORT_PATH gefunden." >&2
  exit 1
fi

APP_IN_ARCHIVE="$ARCHIVE_PATH/Products/Applications/ReiseniOS.app"
if [[ -d "$APP_IN_ARCHIVE" ]]; then
  APS_ENV="$(codesign -d --entitlements :- "$APP_IN_ARCHIVE" 2>/dev/null \
    | plutil -extract aps-environment raw -o - - 2>/dev/null || true)"
  if [[ "$APS_ENV" != "production" ]]; then
    echo "Warnung: aps-environment im Archive ist nicht 'production' (ist: ${APS_ENV:-fehlt})." >&2
  fi

  bash "$ROOT/Scripts/ios-verify-binary-isolation.sh" --mode store --app "$APP_IN_ARCHIVE"
fi

echo "OK: $IPA" >&2
printf '%s\n' "$IPA"
