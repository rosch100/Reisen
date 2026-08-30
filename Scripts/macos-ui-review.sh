#!/usr/bin/env bash
# On-demand macOS UI-Review-Tour (kein CI-Gate). Schreibt PNG + AX-JSON + Manifest.
# bash 3.2 + set -u: niemals ein leeres Array via "${arr[@]}" expandieren.
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

args=(
  -project "$PROJECT"
  -scheme "$SCHEME"
  -destination "$DESTINATION"
  -derivedDataPath "$DERIVED"
  -configuration Debug
  -only-testing:ReisenMacUITests/MacUIReviewTourTests
  -resultBundlePath "$RESULT"
)
if [[ "${CI:-}" == "true" || "${GITHUB_ACTIONS:-}" == "true" ]]; then
  args+=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO)
fi
args+=(test)

echo "macOS-UI-Review: Artifacts → ${REISEN_UI_REVIEW_DIR}" >&2
xcodebuild "${args[@]}"

EXPORT_DIR="$REISEN_UI_REVIEW_DIR/$(date -u +%Y-%m-%dT%H-%M-%SZ)"
mkdir -p "$EXPORT_DIR"
xcrun xcresulttool export attachments \
  --path "$RESULT" \
  --output-path "$EXPORT_DIR"

if ! command -v jq >/dev/null 2>&1; then
  echo "Fehler: jq wird für den Attachment-Export benötigt." >&2
  exit 1
fi
while IFS=$'\t' read -r exported suggested; do
  [[ -n "$exported" && -n "$suggested" ]] || continue
  base="${suggested%%_0_*}"
  extension="${suggested##*.}"
  target="$EXPORT_DIR/$base.$extension"
  if [[ "$exported" != "$suggested" ]]; then
    mv "$EXPORT_DIR/$exported" "$target"
  fi
done < <(jq -r '.[]?.attachments[]? | [.exportedFileName, .suggestedHumanReadableName] | @tsv' "$EXPORT_DIR/manifest.json")

for required in populated.png populated.ax.json chrome.png chrome.ax.json empty.png empty.ax.json; do
  if [[ ! -f "$EXPORT_DIR/$required" ]]; then
    echo "Fehler: Review-Artifact fehlt: $EXPORT_DIR/$required" >&2
    exit 1
  fi
done

cat > "$EXPORT_DIR/manifest.json" <<EOF
{
  "schemaVersion": 1,
  "platform": "macOS",
  "artifacts": [
    "populated.png",
    "populated.ax.json",
    "chrome.png",
    "chrome.ax.json",
    "empty.png",
    "empty.ax.json"
  ]
}
EOF
echo "macOS-UI-Review: Artifacts exportiert → $EXPORT_DIR" >&2
