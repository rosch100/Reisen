#!/usr/bin/env bash
# Validiert ein Store-IPA mit Apples altool --validate-app (ITMS), ohne Review-Upload.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <Store-IPA>" >&2
  exit 1
fi

IPA="$1"
if [[ ! -f "$IPA" ]]; then
  echo "Fehler: Store-IPA fehlt: ${IPA}" >&2
  echo "Zuerst erzeugen (Stdout ist der IPA-Pfad): bash ./Scripts/ios-archive-appstore.sh" >&2
  echo "Dann: bash ./Scripts/ios-validate-appstore.sh \"\$IPA\"" >&2
  exit 1
fi

IPA_NAME="$(basename "$IPA")"
case "$IPA_NAME" in
  *Private*|*private*)
    echo "Fehler: App Store Check validiert nur das Store-IPA, nicht: ${IPA_NAME}" >&2
    exit 1
    ;;
esac

# shellcheck source=apple-developer.sh
source "$ROOT/Scripts/apple-developer.sh"

if [[ -z "${APP_STORE_CONNECT_API_KEY_KEY_ID:-}" ||
      -z "${APP_STORE_CONNECT_API_KEY_ISSUER:-}" ]]; then
  echo "Fehler: APP_STORE_CONNECT_API_KEY_KEY_ID und ISSUER fehlen für altool --validate-app." >&2
  exit 1
fi

reisen_xcodebuild_asc_auth_args
if ! key_path="$(reisen_asc_auth_key_path)"; then
  echo "Fehler: App Store Connect API-Key fehlt für altool --validate-app." >&2
  exit 1
fi

JSON_OUT="$(mktemp "${TMPDIR:-/tmp}/reisen-altool-validate.XXXXXX.json")"
reisen_validate_cleanup() {
  rm -f "$JSON_OUT"
  reisen_cleanup_asc_auth_key
}
trap reisen_validate_cleanup EXIT

ALTOOL_ARGS=(
  --validate-app
  -f "$IPA"
  -t ios
  --apiKey "$APP_STORE_CONNECT_API_KEY_KEY_ID"
  --apiIssuer "$APP_STORE_CONNECT_API_KEY_ISSUER"
  --output-format json
)
if [[ -n "${APP_STORE_CONNECT_APPLE_ID:-}" ]]; then
  ALTOOL_ARGS+=(--apple-id "$APP_STORE_CONNECT_APPLE_ID")
fi

echo "altool --validate-app (ITMS, kein Upload zur Review) …" >&2
set +e
env API_PRIVATE_KEYS_DIR="$(dirname "$key_path")" \
  xcrun altool \
  "${ALTOOL_ARGS[@]}" \
  >"$JSON_OUT" \
  2>&1
ALTOOL_STATUS=$?
set -e

if [[ -s "$JSON_OUT" ]]; then
  cat "$JSON_OUT" >&2
fi

if grep -q 'Unsupported SDK or Xcode version\|"code" *: *90534' "$JSON_OUT"; then
  echo "Fehler: ITMS 90534 — IPA mit nicht akzeptierter Xcode/SDK-Version." >&2
  echo "Dieses Mac: $(xcodebuild -version 2>/dev/null | tr '\n' ' ')" >&2
  echo "Apple akzeptiert nur die neueste Xcode-27-Beta oder RC (nicht ältere Betas)." >&2
  echo "Update: https://developer.apple.com/download/  — aktuelle Builds: https://developer.apple.com/news/releases/" >&2
  echo "Danach Store-IPA neu archivieren und erneut validieren." >&2
fi

if [[ "$ALTOOL_STATUS" -ne 0 ]]; then
  if grep -q "Unable to find Apple ID for Bundle ID" "$JSON_OUT"; then
    echo "Fehler: In App Store Connect fehlt eine iOS-App für Bundle-ID de.roschmac.Reisen.ios." >&2
    echo "Developer-Portal-App-ID reicht nicht. Unter https://appstoreconnect.apple.com/apps eine neue iOS-App anlegen (Bundle-ID de.roschmac.Reisen.ios)." >&2
    echo "Falls die App existiert: API-Key auf „All Apps“ stellen oder die numerische Apple-ID (App Information) als APP_STORE_CONNECT_APPLE_ID setzen." >&2
  fi
  echo "Fehler: altool --validate-app ist fehlgeschlagen (Exit ${ALTOOL_STATUS})." >&2
  exit 1
fi

python3 "$ROOT/Scripts/ios-validate-appstore-report.py" <"$JSON_OUT"
echo "OK: Apple ITMS-Validierung ohne product-errors." >&2
