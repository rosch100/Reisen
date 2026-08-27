#!/usr/bin/env bash
# Release-Build für Store/Private + Binary-Isolation-Check (ohne Archive/IPA).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SIMULATOR_NAME="${IOS_SIMULATOR:-iPad Pro 13-inch (M5)}"
PROJECT="$ROOT/Reisen.xcodeproj"

bash "$ROOT/Scripts/generate-ios-project.sh"

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
  FALLBACK_LINE="$(xcrun simctl list devices available \
    | grep -E 'iPhone|iPad' \
    | grep -v unavailable \
    | head -1 || true)"
  UDID="$(printf '%s\n' "$FALLBACK_LINE" | sed -E 's/.*\(([0-9A-Fa-f-]{36})\).*/\1/' || true)"
fi

if [[ -z "${UDID}" ]]; then
  echo "Fehler: Kein iOS-Simulator für Release-Check gefunden." >&2
  exit 1
fi

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b

build_and_verify() {
  local scheme="$1"
  local product="$2"
  local mode="$3"
  local derived="$ROOT/DerivedData/ios-release-check-${scheme}"

  rm -rf "$derived"

  echo "Release-Build: ${scheme} …" >&2
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$scheme" \
    -configuration Release \
    -destination "platform=iOS Simulator,id=$UDID" \
    -derivedDataPath "$derived" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    build

  local app_path
  app_path="$(find "$derived/Build/Products/Release-iphonesimulator" -maxdepth 1 -name "${product}.app" -print -quit)"
  if [[ -z "$app_path" ]]; then
    echo "Fehler: ${product}.app nicht gefunden unter $derived" >&2
    exit 1
  fi

  local main_binary="$app_path/$product"
  if [[ ! -f "$main_binary" ]]; then
    echo "Fehler: Hauptbinary fehlt in ${product}.app: $main_binary" >&2
    exit 1
  fi

  bash "$ROOT/Scripts/ios-verify-binary-isolation.sh" --mode "$mode" --app "$app_path"
}

build_and_verify ReiseniOS ReiseniOS store
build_and_verify ReiseniOSPrivate ReiseniOSPrivate private

echo "OK: Release-Builds und Binary-Isolation-Checks für Store und Private." >&2
