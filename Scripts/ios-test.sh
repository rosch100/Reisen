#!/usr/bin/env bash
# Führt iOS-Unit-Tests auf dem Simulator aus (SSOT).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SIMULATOR_NAME="${IOS_SIMULATOR:-iPad Pro 13-inch (M5)}"
SCHEME="ReiseniOS"
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
  test
