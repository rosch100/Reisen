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
resolve_udid() {
  local name="$1"
  xcrun simctl list devices available \
    | grep -F "$name (" \
    | head -1 \
    | sed -E 's/.*\(([0-9A-Fa-f-]{36})\).*/\1/' \
    || true
}

UDID="$(resolve_udid "$SIMULATOR_NAME")"

if [[ -z "${UDID}" ]]; then
  if [[ "${CI:-}" == "true" || "${GITHUB_ACTIONS:-}" == "true" ]]; then
    # CI images may lack the local default device; pick first available iPhone/iPad.
    FALLBACK_LINE="$(xcrun simctl list devices available \
      | grep -E 'iPhone|iPad' \
      | grep -v unavailable \
      | head -1 || true)"
    UDID="$(printf '%s\n' "$FALLBACK_LINE" | sed -E 's/.*\(([0-9A-Fa-f-]{36})\).*/\1/' || true)"
    if [[ -n "${UDID}" ]]; then
      echo "Hinweis: ${SIMULATOR_NAME} fehlt — CI-Fallback: ${FALLBACK_LINE}" >&2
    fi
  fi
fi

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
