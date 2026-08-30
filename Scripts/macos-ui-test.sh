#!/usr/bin/env bash
# macOS XCUI-Smokes (SSOT). Host: XcodeGen-Scheme ReisenMac.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export REISEN_GITHUB_ISSUE_TOKEN_EMPTY=true
unset REISEN_EMBED_GITHUB_ISSUE_TOKEN
unset REISEN_REQUIRE_GITHUB_ISSUE_TOKEN
bash "$ROOT/Scripts/generate-ios-project.sh"

PROJECT="$ROOT/Reisen.xcodeproj"
SCHEME="ReisenMac"
DERIVED="$ROOT/DerivedData/ReisenMacUITests"
RESULT="$DERIVED/macos-ui.xcresult"
LOG="$DERIVED/macos-ui-xcodebuild.log"
DESTINATION="${REISEN_MAC_DESTINATION:-platform=macOS}"

mkdir -p "$DERIVED"
rm -rf "$RESULT" "$LOG"

XCODEBUILD_SIGN_ARGS=()
if [[ "${CI:-}" == "true" || "${GITHUB_ACTIONS:-}" == "true" ]]; then
  XCODEBUILD_SIGN_ARGS+=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO)
fi

run_ui_tests() {
  local extra_sign=("$@")
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED" \
    -configuration Debug \
    -only-testing:ReisenMacUITests \
    -resultBundlePath "$RESULT" \
    "${XCODEBUILD_SIGN_ARGS[@]}" \
    "${extra_sign[@]}" \
    test
}

echo "macOS-UI-Tests: ${SCHEME} (${DESTINATION}) …" >&2
set +e
run_ui_tests 2>&1 | tee "$LOG"
status=${PIPESTATUS[0]}
set -e

if [[ "$status" -ne 0 ]]; then
  if grep -Eiq 'failed to attach|could not attach|not code signed|errSec|DTServiceHub' "$LOG"; then
    echo "Hinweis: Signing/Attach fehlgeschlagen — Retry mit Ad-hoc CODE_SIGN_IDENTITY=-" >&2
    rm -rf "$RESULT"
    set +e
    run_ui_tests CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tee -a "$LOG"
    status=${PIPESTATUS[0]}
    set -e
  fi
fi

if [[ "$status" -ne 0 ]]; then
  echo "Fehler: macOS-UI-Tests fehlgeschlagen (Exit ${status}). xcresult: ${RESULT}" >&2
  exit "$status"
fi
