#!/usr/bin/env bash
# Lädt ein iOS-IPA nach App Store Connect hoch (TestFlight-Processing).
# Für Private-iOS nur Internal Testing zuweisen — nie External Testing / Public Link.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <IPA>" >&2
  echo "Private Internal TF: IPA=\$(bash ./Scripts/ios-archive-private-testflight.sh) && bash ./Scripts/ios-upload-testflight.sh \"\$IPA\"" >&2
  exit 1
fi

IPA="$1"
if [[ ! -f "$IPA" ]]; then
  echo "Fehler: IPA fehlt: ${IPA}" >&2
  exit 1
fi

# shellcheck source=apple-developer.sh
source "$ROOT/Scripts/apple-developer.sh"

if [[ -z "${APP_STORE_CONNECT_API_KEY_KEY_ID:-}" ||
      -z "${APP_STORE_CONNECT_API_KEY_ISSUER:-}" ]]; then
  echo "Fehler: APP_STORE_CONNECT_API_KEY_KEY_ID und ISSUER fehlen für altool --upload-app." >&2
  exit 1
fi

reisen_xcodebuild_asc_auth_args
if ! key_path="$(reisen_asc_auth_key_path)"; then
  echo "Fehler: App Store Connect API-Key fehlt für altool --upload-app." >&2
  exit 1
fi

trap reisen_cleanup_asc_auth_key EXIT

IPA_NAME="$(basename "$IPA")"
case "$IPA_NAME" in
  *Private*|*private*)
    echo "Hinweis: Private-IPA — nach Processing nur Internal Testing zuweisen (kein External/Public Link)." >&2
    ;;
esac

ALTOOL_ARGS=(
  --upload-app
  -f "$IPA"
  -t ios
  --apiKey "$APP_STORE_CONNECT_API_KEY_KEY_ID"
  --apiIssuer "$APP_STORE_CONNECT_API_KEY_ISSUER"
)
if [[ -n "${APP_STORE_CONNECT_APPLE_ID:-}" ]]; then
  ALTOOL_ARGS+=(--apple-id "$APP_STORE_CONNECT_APPLE_ID")
fi

echo "altool --upload-app → App Store Connect (TestFlight Processing) …" >&2
env API_PRIVATE_KEYS_DIR="$(dirname "$key_path")" \
  xcrun altool \
  "${ALTOOL_ARGS[@]}" \
  >&2

echo "OK: Upload gestartet/abgeschlossen für $IPA" >&2
echo "Als Nächstes in App Store Connect → TestFlight → Internal Testing (nie External)." >&2
