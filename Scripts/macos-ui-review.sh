#!/usr/bin/env bash
# On-demand macOS UI-Review-Tour (kein CI-Gate). Schreibt PNG + AX-JSON + Manifest.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export REISEN_UI_REVIEW=1
export REISEN_UI_REVIEW_DIR="${REISEN_UI_REVIEW_DIR:-$ROOT/DerivedData/ui-review}"
mkdir -p "$REISEN_UI_REVIEW_DIR"

export REISEN_GITHUB_ISSUE_TOKEN_EMPTY=true
unset REISEN_EMBED_GITHUB_ISSUE_TOKEN
unset REISEN_REQUIRE_GITHUB_ISSUE_TOKEN
bash "$ROOT/Scripts/generate-ios-project.sh"

PROJECT="$ROOT/Reisen.xcodeproj"
SCHEME="ReisenMac"
DERIVED="$ROOT/DerivedData/ReisenMacUIReview"
RESULT="$DERIVED/macos-ui-review.xcresult"
DESTINATION="${REISEN_MAC_DESTINATION:-platform=macOS}"

mkdir -p "$DERIVED"
rm -rf "$RESULT"

XCODEBUILD_SIGN_ARGS=()
if [[ "${CI:-}" == "true" || "${GITHUB_ACTIONS:-}" == "true" ]]; then
  XCODEBUILD_SIGN_ARGS+=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO)
fi

echo "macOS-UI-Review: Artifacts → ${REISEN_UI_REVIEW_DIR}" >&2
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED" \
  -configuration Debug \
  -only-testing:ReisenMacUITests/MacUIReviewTourTests \
  -resultBundlePath "$RESULT" \
  "${XCODEBUILD_SIGN_ARGS[@]}" \
  test
