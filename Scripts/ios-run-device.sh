#!/usr/bin/env bash
# Baut und startet ReiseniOS bzw. ReiseniOSPrivate (Vendor-Sync) auf einem physischen Gerät.
# Usage: ios-run-device.sh [--private]
# Env: IOS_SCHEME=ReiseniOS|ReiseniOSPrivate (Default: ReiseniOS; --private → ReiseniOSPrivate)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# shellcheck source=apple-developer.sh
source "$ROOT/Scripts/apple-developer.sh"

SCHEME="${IOS_SCHEME:-ReiseniOS}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --private)
      SCHEME="ReiseniOSPrivate"
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [--private]" >&2
      echo "  --private  ReiseniOSPrivate (Vendor-Sync); Default: ReiseniOS (Store)" >&2
      echo "  IOS_SCHEME=ReiseniOS|ReiseniOSPrivate" >&2
      exit 0
      ;;
    *)
      echo "Fehler: Unbekanntes Argument: $1" >&2
      echo "Usage: $0 [--private]" >&2
      exit 2
      ;;
  esac
done

case "$SCHEME" in
  ReiseniOS|ReiseniOSPrivate) ;;
  *)
    echo "Fehler: Unbekanntes Scheme: $SCHEME (ReiseniOS, ReiseniOSPrivate)" >&2
    exit 2
    ;;
esac

BUNDLE_ID="$(reisen_bundle_id_for_target "$SCHEME")"
APP_PRODUCT_NAME="$SCHEME"
PROJECT="$ROOT/Reisen.xcodeproj"
DERIVED="$ROOT/DerivedData/${SCHEME}-device"

list_physical_devices() {
  local json
  json="$(mktemp)"
  xcrun devicectl list devices --json-output "$json" --timeout 15 >/dev/null
  python3 - "$json" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    devices = json.load(f)["result"]["devices"]
for d in devices:
    hw = d.get("hardwareProperties") or {}
    conn = d.get("connectionProperties") or {}
    props = d.get("deviceProperties") or {}
    if hw.get("reality") != "physical":
        continue
    if hw.get("platform") != "iOS":
        continue
    name = props.get("name") or d.get("identifier")
    udid = hw.get("udid") or ""
    ident = d.get("identifier") or ""
    tunnel = conn.get("tunnelState") or "unavailable"
    print(f"{tunnel}\t{name}\t{udid}\t{ident}")
PY
  rm -f "$json"
}

DEVICE_LIST="$(mktemp)"
list_physical_devices >"$DEVICE_LIST"

DEVICE_NAME=""
DEVICE_UDID=""
DEVICE_IDENT=""
while IFS=$'\t' read -r tunnel name udid ident; do
  [[ -z "${name:-}" ]] && continue
  echo "Gerät: ${name}  UDID=${udid}  Status=${tunnel}" >&2
  if [[ "$tunnel" == "connected" && -z "$DEVICE_UDID" ]]; then
    DEVICE_NAME="$name"
    DEVICE_UDID="$udid"
    DEVICE_IDENT="$ident"
  fi
done <"$DEVICE_LIST"
rm -f "$DEVICE_LIST"

if [[ -z "$DEVICE_UDID" ]]; then
  echo "Fehler: Kein verbundenes physisches iOS-Gerät." >&2
  echo "Dann:" >&2
  echo "  1. iPhone entsperren, diesem Mac vertrauen" >&2
  echo "  2. Einstellungen, Datenschutz und Sicherheit, Entwicklermodus einschalten" >&2
  echo "  3. bash ./Scripts/ios-run-device.sh [--private]" >&2
  exit 1
fi

unset REISEN_GITHUB_ISSUE_TOKEN_EMPTY
export REISEN_EMBED_GITHUB_ISSUE_TOKEN=true
bash "$ROOT/Scripts/generate-ios-project.sh"

TEAM_ID="$(reisen_apple_team_id)"
reisen_xcodebuild_asc_device_auth_args

echo "Baue ${SCHEME} für ${DEVICE_NAME} (${DEVICE_UDID})…" >&2
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "platform=iOS,id=${DEVICE_UDID}" \
  -derivedDataPath "$DERIVED" \
  -configuration Debug \
  "${REISEN_ASC_AUTH_ARGS[@]}" \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  build

APP_PATH="$(find "$DERIVED" -path "*/Debug-iphoneos/${APP_PRODUCT_NAME}.app" -type d | head -1)"
if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "Fehler: ${APP_PRODUCT_NAME}.app (iphoneos) nicht unter DerivedData gefunden." >&2
  exit 1
fi

echo "Installiere ${SCHEME} (${BUNDLE_ID}) auf ${DEVICE_NAME}…" >&2
xcrun devicectl device install app --device "$DEVICE_IDENT" "$APP_PATH"
echo "Starte ${BUNDLE_ID}…" >&2
xcrun devicectl device process launch --device "$DEVICE_IDENT" "$BUNDLE_ID"

echo "OK: $BUNDLE_ID ($SCHEME) auf $DEVICE_NAME ($DEVICE_UDID)"
