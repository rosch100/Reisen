#!/usr/bin/env bash
# Erzeugt ein App-Store-Archive und exportiert ein IPA (mit eingebettetem Issues-PAT).
# Stdout ist nur der IPA-Pfad; Build-Logs gehen nach stderr (CI-Command-Substitution).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SCHEME="ReiseniOS"
PROJECT="$ROOT/Reisen.xcodeproj"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT/.build/ReiseniOS.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$ROOT/.build/ReiseniOS-ipa}"
EXPORT_OPTIONS="${EXPORT_OPTIONS:-$ROOT/Scripts/ios-export-appstore.plist}"

export REISEN_EMBED_GITHUB_ISSUE_TOKEN=true
export REISEN_REQUIRE_GITHUB_ISSUE_TOKEN=true
unset REISEN_GITHUB_ISSUE_TOKEN_EMPTY

# shellcheck source=apple-developer.sh
source "$ROOT/Scripts/apple-developer.sh"

TEAM_ID="$(reisen_apple_team_id)"
reisen_xcodebuild_asc_auth_args
if [[ "${GITHUB_ACTIONS:-}" == "true" ]] && ! reisen_asc_auth_key_path >/dev/null; then
  echo "Fehler: GitHub Actions Archive braucht APP_STORE_CONNECT_API_KEY_BASE64, KEY_ID und ISSUER." >&2
  exit 1
fi

bash "$ROOT/Scripts/generate-ios-project.sh" >&2

if [[ ! -f "$EXPORT_OPTIONS" ]]; then
  echo "Fehler: ExportOptions fehlt: $EXPORT_OPTIONS" >&2
  exit 1
fi

mkdir -p "$(dirname "$ARCHIVE_PATH")"
rm -rf "$EXPORT_PATH"
mkdir -p "$EXPORT_PATH"

# Homebrew rsync 3.x versteht Xcodes -E/--extended-attributes nicht
# (exportArchive: Copy failed). /usr/bin/rsync (openrsync) muss zuerst kommen.
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:${PATH}"

echo "Archive (Release, generic iOS) …" >&2
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE_PATH" \
  archive \
  "${REISEN_ASC_AUTH_ARGS[@]}" \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  >&2

echo "Export IPA (app-store) …" >&2
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  "${REISEN_ASC_AUTH_ARGS[@]}" \
  >&2

IPA_FILES=()
while IFS= read -r -d '' ipa_file; do
  IPA_FILES+=("$ipa_file")
done < <(find "$EXPORT_PATH" -maxdepth 1 -name '*.ipa' -print0)
if ((${#IPA_FILES[@]} != 1)); then
  echo "Fehler: erwartet genau ein Store-IPA unter $EXPORT_PATH, gefunden: ${#IPA_FILES[@]}." >&2
  exit 1
fi
IPA="${IPA_FILES[0]}"

APP_IN_ARCHIVE="$ARCHIVE_PATH/Products/Applications/${SCHEME}.app"
if [[ ! -d "$APP_IN_ARCHIVE" ]]; then
  echo "Fehler: Store-.app fehlt im Archive: $APP_IN_ARCHIVE" >&2
  exit 1
fi

APS_ENV="$(codesign -d --entitlements :- "$APP_IN_ARCHIVE" 2>/dev/null \
  | plutil -extract aps-environment raw -o - - 2>/dev/null || true)"
if [[ "$APS_ENV" != "production" ]]; then
  echo "Warnung: aps-environment im Archive ist nicht 'production' (ist: ${APS_ENV:-fehlt})." >&2
fi

bash "$ROOT/Scripts/ios-verify-binary-isolation.sh" --mode store --app "$APP_IN_ARCHIVE" >&2
bash "$ROOT/Scripts/ios-verify-binary-isolation.sh" --mode store --ipa "$IPA" >&2

echo "OK: $IPA" >&2
printf '%s\n' "$IPA"
