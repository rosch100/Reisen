#!/usr/bin/env bash
# macOS XCUI-Smokes (SSOT). Host: XcodeGen-Scheme ReisenMac.
# bash 3.2 + set -u: niemals ein leeres Array via "${arr[@]}" expandieren.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

reisen_macos_ui_xcodebuild_args() {
  local project="$1"
  local scheme="$2"
  local destination="$3"
  local derived="$4"
  local result="$5"
  shift 5
  local -a args
  args=(
    -project "$project"
    -scheme "$scheme"
    -destination "$destination"
    -derivedDataPath "$derived"
    -configuration Debug
    -only-testing:ReisenMacUITests
    -resultBundlePath "$result"
  )
  if [[ "${CI:-}" == "true" || "${GITHUB_ACTIONS:-}" == "true" ]]; then
    args+=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO)
  fi
  if (($#)); then
    args+=("$@")
  fi
  args+=(test)
  printf '%s\n' "${args[@]}"
}

if [[ "${1:-}" == "--self-test" ]]; then
  unset CI GITHUB_ACTIONS
  local_out="$(reisen_macos_ui_xcodebuild_args /p S 'platform=macOS' /d /r.xcresult)"
  printf '%s\n' "$local_out" | grep -qx -- -project
  printf '%s\n' "$local_out" | grep -qx test
  if printf '%s\n' "$local_out" | grep -q CODE_SIGNING_ALLOWED=NO; then
    echo "self-test: lokales Signing-Flag ohne CI" >&2
    exit 1
  fi
  CI=true
  ci_out="$(reisen_macos_ui_xcodebuild_args /p S 'platform=macOS' /d /r.xcresult)"
  printf '%s\n' "$ci_out" | grep -qx CODE_SIGNING_ALLOWED=NO
  printf '%s\n' "$ci_out" | grep -qx CODE_SIGNING_REQUIRED=NO
  extra_out="$(reisen_macos_ui_xcodebuild_args /p S 'platform=macOS' /d /r.xcresult CODE_SIGN_IDENTITY=-)"
  printf '%s\n' "$extra_out" | grep -qx CODE_SIGN_IDENTITY=-
  echo "macos-ui-test.sh self-test: OK" >&2
  exit 0
fi

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

run_ui_tests() {
  local -a args
  while IFS= read -r line; do
    args+=("$line")
  done < <(reisen_macos_ui_xcodebuild_args "$PROJECT" "$SCHEME" "$DESTINATION" "$DERIVED" "$RESULT" "$@")
  xcodebuild "${args[@]}"
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
