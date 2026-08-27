#!/usr/bin/env bash
# Erzeugt ein Ad-Hoc-Archive der Private-iOS-App (voller Provider-Sync, kein App-Store-Review).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SCHEME="ReiseniOSPrivate"
PROJECT="$ROOT/Reisen.xcodeproj"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT/.build/ReiseniOSPrivate.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$ROOT/.build/ReiseniOSPrivate-ipa}"
EXPORT_OPTIONS="${EXPORT_OPTIONS:-$ROOT/Scripts/ios-export-adhoc.plist}"

export REISEN_EMBED_GITHUB_ISSUE_TOKEN=true
export REISEN_REQUIRE_GITHUB_ISSUE_TOKEN=true
unset REISEN_GITHUB_ISSUE_TOKEN_EMPTY

bash "$ROOT/Scripts/generate-ios-project.sh"

if [[ ! -f "$EXPORT_OPTIONS" ]]; then
  echo "Fehler: ExportOptions fehlt: $EXPORT_OPTIONS" >&2
  exit 1
fi

mkdir -p "$(dirname "$ARCHIVE_PATH")"
mkdir -p "$EXPORT_PATH"

echo "Archive Private-iOS (Release, generic iOS) …" >&2
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE_PATH" \
  archive \
  -allowProvisioningUpdates

echo "Export IPA (ad-hoc) …" >&2
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

APP_IN_ARCHIVE="$ARCHIVE_PATH/Products/Applications/ReiseniOSPrivate.app"
if [[ -d "$APP_IN_ARCHIVE" ]]; then
  bash "$ROOT/Scripts/ios-verify-binary-isolation.sh" --mode private --app "$APP_IN_ARCHIVE"
fi

echo "OK: $IPA" >&2
printf '%s\n' "$IPA"
