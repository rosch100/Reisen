#!/usr/bin/env bash
# macOS XCUI-Smokes (SSOT). Host: XcodeGen-Scheme ReisenMac.
# bash 3.2 + set -u: niemals ein leeres Array via "${arr[@]}" expandieren.
#
# REISEN_MAC_UI_CODE_SIGNING_OFF=true (Remote ohne Developer-Profile):
#   build-for-testing ohne Signatur → Ad-hoc codesign + xattr -cr →
#   test-without-building.
#   CODE_SIGNING_ALLOWED=NO allein + Start unter Gatekeeper → Dialog
#   „… ist beschädigt und kann nicht geöffnet werden“.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

reisen_macos_ui_common_args() {
  local project="$1"
  local scheme="$2"
  local destination="$3"
  local derived="$4"
  local result="$5"
  printf '%s\n' \
    -project "$project" \
    -scheme "$scheme" \
    -destination "$destination" \
    -derivedDataPath "$derived" \
    -configuration Debug \
    -only-testing:ReisenMacUITests/MacUISmokeTests \
    -resultBundlePath "$result"
}

reisen_macos_ui_xcodebuild_args() {
  local project="$1"
  local scheme="$2"
  local destination="$3"
  local derived="$4"
  local result="$5"
  shift 5
  local -a args
  while IFS= read -r line; do
    args+=("$line")
  done < <(reisen_macos_ui_common_args "$project" "$scheme" "$destination" "$derived" "$result")
  if [[ "${CI:-}" == "true" || "${GITHUB_ACTIONS:-}" == "true" ]]; then
    args+=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO)
  fi
  if (($#)); then
    args+=("$@")
  fi
  args+=(test)
  printf '%s\n' "${args[@]}"
}

reisen_macos_ui_clear_gatekeeper_attrs() {
  local derived="$1"
  local products="${derived}/Build/Products"
  [[ -d "$products" ]] || return 0
  xattr -cr "$products" 2>/dev/null || true
}

reisen_macos_ui_adhoc_resign_products() {
  local derived="$1"
  local products="${derived}/Build/Products"
  local bundle ents failed=0
  [[ -d "$products" ]] || return 0
  ents="$(mktemp -t reisen-ui-empty-ents.XXXXXX)"
  cat >"$ents" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict/></plist>
PLIST
  while IFS= read -r -d '' bundle; do
    # Ohne Entitlements: Development-Cert-Pflicht entfällt; Gatekeeper braucht Signatur.
    if ! codesign --force --deep --sign - --entitlements "$ents" "$bundle" >/dev/null 2>&1 \
      && ! codesign --force --deep --sign - "$bundle" >/dev/null 2>&1; then
      echo "Fehler: Ad-hoc codesign fehlgeschlagen: $bundle" >&2
      failed=1
    fi
  done < <(find "$products" \( -name '*.app' -o -name '*.xctest' \) -print0 2>/dev/null)
  rm -f "$ents"
  [[ "$failed" -eq 0 ]] || return 1
}

reisen_macos_ui_run_unsigned_build_then_adhoc_test() {
  # Remote-Pfad: unsigned build (Entitlements ok) → Ad-hoc sign → test ohne Rebuild.
  local project="$1"
  local scheme="$2"
  local destination="$3"
  local derived="$4"
  local result="$5"
  local -a common
  while IFS= read -r line; do
    common+=("$line")
  done < <(reisen_macos_ui_common_args "$project" "$scheme" "$destination" "$derived" "$result")

  echo "macOS-UI-Tests: build-for-testing (unsigned) …" >&2
  xcodebuild "${common[@]}" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
    build-for-testing || return $?

  echo "macOS-UI-Tests: Ad-hoc codesign + xattr -cr …" >&2
  reisen_macos_ui_clear_gatekeeper_attrs "$derived"
  reisen_macos_ui_adhoc_resign_products "$derived" || return $?
  rm -rf "$result"

  echo "macOS-UI-Tests: test-without-building …" >&2
  xcodebuild "${common[@]}" test-without-building
}

if [[ "${1:-}" == "--self-test" ]]; then
  unset CI GITHUB_ACTIONS REISEN_MAC_UI_CODE_SIGNING_OFF
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

REISEN_CI_T0="$(date +%s)"
trap 'echo "reisen-ci-duration: script=macos-ui-test.sh seconds=$(( $(date +%s) - REISEN_CI_T0 ))" >&2' EXIT

export REISEN_GITHUB_ISSUE_TOKEN_EMPTY=true
unset REISEN_EMBED_GITHUB_ISSUE_TOKEN
unset REISEN_REQUIRE_GITHUB_ISSUE_TOKEN
if [[ "${REISEN_SKIP_GENERATE_IOS_PROJECT:-}" != "1" ]]; then
  bash "$ROOT/Scripts/generate-ios-project.sh"
elif [[ ! -d "$ROOT/Reisen.xcodeproj" ]]; then
  echo "Fehler: REISEN_SKIP_GENERATE_IOS_PROJECT=1 aber Reisen.xcodeproj fehlt." >&2
  exit 1
fi

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
if [[ "${REISEN_MAC_UI_CODE_SIGNING_OFF:-}" == "true" ]]; then
  reisen_macos_ui_run_unsigned_build_then_adhoc_test \
    "$PROJECT" "$SCHEME" "$DESTINATION" "$DERIVED" "$RESULT" 2>&1 | tee "$LOG"
  status=${PIPESTATUS[0]}
else
  run_ui_tests 2>&1 | tee "$LOG"
  status=${PIPESTATUS[0]}
fi
set -e

reisen_macos_ui_clear_gatekeeper_attrs "$DERIVED"

if [[ "$status" -ne 0 && "${REISEN_MAC_UI_CODE_SIGNING_OFF:-}" != "true" ]]; then
  if grep -Eiq 'failed to attach|could not attach|not code signed|errSec|DTServiceHub|bootstrapping|signal kill|Early unexpected exit|beschädigt|damaged|cannot be opened' "$LOG"; then
    echo "Hinweis: Signing/Attach/Gatekeeper — Retry mit Ad-hoc-Resign-Pfad" >&2
    rm -rf "$RESULT"
    set +e
    REISEN_MAC_UI_CODE_SIGNING_OFF=true reisen_macos_ui_run_unsigned_build_then_adhoc_test \
      "$PROJECT" "$SCHEME" "$DESTINATION" "$DERIVED" "$RESULT" 2>&1 | tee -a "$LOG"
    status=${PIPESTATUS[0]}
    set -e
    reisen_macos_ui_clear_gatekeeper_attrs "$DERIVED"
  fi
fi

if [[ "$status" -ne 0 ]]; then
  echo "Fehler: macOS-UI-Tests fehlgeschlagen (Exit ${status}). xcresult: ${RESULT}" >&2
  exit "$status"
fi
