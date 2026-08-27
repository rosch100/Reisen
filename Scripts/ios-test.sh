#!/usr/bin/env bash
# Führt iOS-Unit-Tests auf dem Simulator aus (SSOT).
# IOS_SCHEME: all (default), ReiseniOS, ReiseniOSPrivate.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

run_scheme_tests() {
  local scheme="$1"
  local derived="$ROOT/DerivedData/${scheme}"

  echo "iOS-Tests: ${scheme} …" >&2
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$scheme" \
    -destination "platform=iOS Simulator,id=$UDID" \
    -derivedDataPath "$derived" \
    -configuration Debug \
    "${XCODEBUILD_SIGN_ARGS[@]}" \
    test
}

SIMULATOR_NAME="${IOS_SIMULATOR:-iPad Pro 13-inch (M5)}"
SCHEME="${IOS_SCHEME:-all}"
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
  if [[ "${CI:-}" == "true" || "${GITHUB_ACTIONS:-}" == "true" ]]; then
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

XCODEBUILD_SIGN_ARGS=()
if [[ "${CI:-}" == "true" || "${GITHUB_ACTIONS:-}" == "true" ]]; then
  XCODEBUILD_SIGN_ARGS+=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO)
fi

case "$SCHEME" in
  all)
    run_scheme_tests ReiseniOS
    run_scheme_tests ReiseniOSPrivate
    ;;
  ReiseniOS|ReiseniOSPrivate)
    run_scheme_tests "$SCHEME"
    ;;
  *)
    echo "Fehler: Unbekanntes Scheme: $SCHEME (ReiseniOS, ReiseniOSPrivate, all)" >&2
    exit 2
    ;;
esac
