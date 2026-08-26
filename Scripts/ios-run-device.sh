#!/usr/bin/env bash
# Baut und startet ReiseniOS auf einem physischen iOS-Gerät (kein Simulator).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SCHEME="ReiseniOS"
BUNDLE_ID="de.roschmac.Reisen.ios"
PROJECT="$ROOT/Reisen.xcodeproj"
DERIVED="$ROOT/DerivedData/ReiseniOS-device"

# shellcheck source=apple-developer.sh
source "$ROOT/Scripts/apple-developer.sh"

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
  echo "Roland IP ist aktuell nicht erreichbar." >&2
  echo "Dann:" >&2
  echo "  1. iPhone entsperren, diesem Mac vertrauen" >&2
  echo "  2. Einstellungen, Datenschutz und Sicherheit, Entwicklermodus einschalten" >&2
  echo "  3. bash ./Scripts/ios-run-device.sh" >&2
  exit 1
fi

bash "$ROOT/Scripts/generate-ios-project.sh"

TEAM_ID="$(reisen_apple_team_id)"
AUTH_ARGS=()
while IFS= read -r arg; do
  [[ -n "$arg" ]] && AUTH_ARGS+=("$arg")
done < <(reisen_xcodebuild_asc_auth_args || true)
if [[ ${#AUTH_ARGS[@]} -eq 0 ]]; then
  AUTH_ARGS+=(-allowProvisioningUpdates)
fi
AUTH_ARGS+=(-allowProvisioningDeviceRegistration)

echo "Baue ReiseniOS für ${DEVICE_NAME} (${DEVICE_UDID})…" >&2
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "platform=iOS,id=${DEVICE_UDID}" \
  -derivedDataPath "$DERIVED" \
  -configuration Debug \
  "${AUTH_ARGS[@]}" \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  build

APP_PATH="$(find "$DERIVED" -path '*/Debug-iphoneos/ReiseniOS.app' -type d | head -1)"
if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "Fehler: ReiseniOS.app (iphoneos) nicht unter DerivedData gefunden." >&2
  exit 1
fi

echo "Installiere auf ${DEVICE_NAME}…" >&2
xcrun devicectl device install app --device "$DEVICE_IDENT" "$APP_PATH"
echo "Starte ${BUNDLE_ID}…" >&2
xcrun devicectl device process launch --device "$DEVICE_IDENT" "$BUNDLE_ID"

echo "OK: $BUNDLE_ID auf $DEVICE_NAME ($DEVICE_UDID)"
