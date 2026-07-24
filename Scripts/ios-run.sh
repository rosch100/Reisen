#!/usr/bin/env bash
# Baut und startet ReiseniOS auf dem iOS-Simulator (SSOT für Agent/Cursor).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SIMULATOR_NAME="${IOS_SIMULATOR:-iPad Pro 13-inch (M5)}"
SCHEME="ReiseniOS"
BUNDLE_ID="de.roschmac.Reisen.ios"
PROJECT="$ROOT/Reisen.xcodeproj"
DERIVED="$ROOT/DerivedData/ReiseniOS"

bash "$ROOT/Scripts/generate-ios-project.sh"

# Portable UDID parse (BSD sed/grep on macOS; no GNU awk)
UDID="$(xcrun simctl list devices available \
  | grep -F "$SIMULATOR_NAME (" \
  | head -1 \
  | sed -E 's/.*\(([0-9A-Fa-f-]{36})\).*/\1/' \
  || true)"

if [[ -z "${UDID}" ]]; then
  echo "Fehler: Simulator nicht gefunden: ${SIMULATOR_NAME}" >&2
  echo "Verfügbare Geräte:" >&2
  xcrun simctl list devices available >&2
  exit 1
fi

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$DERIVED" \
  -configuration Debug \
  build

APP_PATH="$(find "$DERIVED" -path '*/Debug-iphonesimulator/ReiseniOS.app' -type d | head -1)"
if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "Fehler: ReiseniOS.app nicht unter DerivedData gefunden." >&2
  exit 1
fi

xcrun simctl install "$UDID" "$APP_PATH"
xcrun simctl launch "$UDID" "$BUNDLE_ID"

# Xcode 27+: Simulator.app entfällt → DeviceHub zeigt die Geräte-UI.
# Ältere Xcode: weiterhin Simulator.app.
DEVELOPER_DIR="$(xcode-select -p)"
DEVICE_HUB="${DEVELOPER_DIR%/Contents/Developer}/Contents/Applications/DeviceHub.app"
SIMULATOR_APP="${DEVELOPER_DIR}/Applications/Simulator.app"
if [[ -d "$DEVICE_HUB" ]]; then
  open "$DEVICE_HUB" --args -CurrentDeviceUDID "$UDID" >/dev/null 2>&1 || true
elif [[ -d "$SIMULATOR_APP" ]]; then
  open "$SIMULATOR_APP" --args -CurrentDeviceUDID "$UDID" >/dev/null 2>&1 || true
else
  echo "Hinweis: Weder DeviceHub.app noch Simulator.app gefunden — App läuft headless." >&2
fi

echo "OK: $BUNDLE_ID auf $SIMULATOR_NAME ($UDID)"
