#!/usr/bin/env bash
# Richtet Signing gegen das Apple-Developer-Team für Reisen (macOS + iOS) ein.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# shellcheck source=apple-developer.sh
source "$ROOT/Scripts/apple-developer.sh"

MACOS_BUNDLE_ID="$(reisen_macos_bundle_id)"
IOS_BUNDLE_ID="$(reisen_ios_bundle_id)"
ICLOUD_CONTAINER="$(reisen_icloud_container_id)"

TEAM_ID="$(reisen_apple_team_id)"
echo "Apple Team ID: $TEAM_ID" >&2

IDENTITY="$(reisen_apple_development_identity "$TEAM_ID")"
echo "Apple Development: $IDENTITY" >&2

bash "$ROOT/Scripts/generate-ios-project.sh"

PROJECT="$ROOT/Reisen.xcodeproj"
if ! grep -q "DEVELOPMENT_TEAM = ${TEAM_ID}" "$PROJECT/project.pbxproj"; then
  echo "Fehler: Generiertes Xcode-Projekt enthält DEVELOPMENT_TEAM ${TEAM_ID} nicht." >&2
  exit 1
fi

reisen_xcodebuild_asc_device_auth_args

SIGNING_DERIVED="$ROOT/DerivedData/Reisen-signing"
mkdir -p "$ROOT/.signing"

SIMULATOR_NAME="${IOS_SIMULATOR:-iPad Pro 13-inch (M5)}"
if [[ -z "${IOS_DEVICE_UDID:-}" ]]; then
  IOS_DEVICE_UDID="$(
    xcrun xctrace list devices 2>/dev/null |
      grep -E '\([0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}\)' |
      grep -v Simulator |
      head -1 |
      sed -E 's/.*\(([0-9A-Fa-f]{8}-[0-9A-Fa-f]{16})\).*/\1/' || true
  )"
fi

run_signing_build() {
  local label="$1"
  shift
  echo "${label}…" >&2
  xcodebuild \
    -project "$PROJECT" \
    -derivedDataPath "$SIGNING_DERIVED" \
    -configuration Debug \
    "${REISEN_ASC_AUTH_ARGS[@]}" \
    CODE_SIGN_STYLE=Automatic \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    "$@"
}

provisioning_failed() {
  local detail="$1"
  echo >&2
  echo "Provisioning unvollständig: ${detail}" >&2
  echo >&2
  echo "Nächste Schritte:" >&2
  echo "  1. open $PROJECT" >&2
  echo "  2. Signing & Capabilities: passendes Team wählen (${TEAM_ID})" >&2
  echo "  3. iCloud (CloudKit, Container ${ICLOUD_CONTAINER}) für ${IOS_BUNDLE_ID}, de.reisen.Reisen.ios.private und ${MACOS_BUNDLE_ID}" >&2
  echo "  4. Für iOS-Geräteprofile: iPhone einschalten oder UDID im Developer Portal anlegen" >&2
  echo >&2
  echo "Danach erneut: bash ./Scripts/setup-apple-developer.sh" >&2
}

# Simulator braucht kein Device-Profil; registriert App-ID/Capabilities soweit möglich.
set +e
run_signing_build "Registriere iOS App ID (Simulator)" \
  -scheme ReiseniOS \
  -destination "platform=iOS Simulator,name=${SIMULATOR_NAME}" \
  build >&2
IOS_SIM_STATUS=$?
set -e

if [[ "$IOS_SIM_STATUS" -ne 0 ]]; then
  provisioning_failed "iOS-Simulator-Build fehlgeschlagen"
  exit 1
fi
echo "iOS Simulator-Build ok (${IOS_BUNDLE_ID})." >&2

set +e
run_signing_build "Registriere Private-iOS App ID (Simulator)" \
  -scheme ReiseniOSPrivate \
  -destination "platform=iOS Simulator,name=${SIMULATOR_NAME}" \
  build >&2
IOS_PRIVATE_SIM_STATUS=$?
set -e

if [[ "$IOS_PRIVATE_SIM_STATUS" -ne 0 ]]; then
  provisioning_failed "Private-iOS-Simulator-Build fehlgeschlagen"
  exit 1
fi
echo "Private-iOS Simulator-Build ok (de.reisen.Reisen.ios.private)." >&2

# Physisches Gerät (auch offline) anmelden, damit ein Development-Profil entstehen kann.
if [[ -n "${IOS_DEVICE_UDID:-}" ]]; then
  set +e
  run_signing_build "Registriere iOS-Gerät / Development-Profil (${IOS_DEVICE_UDID})" \
    -scheme ReiseniOS \
    -destination "platform=iOS,id=${IOS_DEVICE_UDID}" \
    build >&2
  IOS_DEVICE_STATUS=$?
  set -e
  if [[ "$IOS_DEVICE_STATUS" -ne 0 ]]; then
    echo "Hinweis: Kein iOS-Geräteprofil (Gerät offline oder UDID nicht im Portal)." >&2
    echo "  Simulator-Entwicklung funktioniert; Gerät verbinden und Script erneut ausführen." >&2
  fi
else
  echo "Hinweis: Kein physisches iOS-Gerät gefunden — Geräteprofil wird übersprungen." >&2
fi

set +e
run_signing_build "Registriere macOS App ID / Profile (dieses Mac als Gerät)" \
  -scheme ReisenMac \
  -destination "platform=macOS,arch=arm64" \
  build >&2
MAC_STATUS=$?
set -e

if [[ "$MAC_STATUS" -ne 0 ]]; then
  provisioning_failed "macOS-Build fehlgeschlagen"
  exit 1
fi

MAC_APP="$(find "$SIGNING_DERIVED" -path '*/Build/Products/Debug/Reisen.app' -type d | head -1 || true)"
PROFILE_SRC=""
if [[ -n "$MAC_APP" && -f "$MAC_APP/Contents/embedded.provisionprofile" ]]; then
  PROFILE_SRC="$MAC_APP/Contents/embedded.provisionprofile"
fi
if [[ -z "$PROFILE_SRC" ]]; then
  PROFILE_SRC="$(find "$SIGNING_DERIVED" -name 'embedded.provisionprofile' | head -1 || true)"
fi
if [[ -z "$PROFILE_SRC" || ! -f "$PROFILE_SRC" ]]; then
  echo "Fehler: macOS-Build lieferte kein embedded.provisionprofile." >&2
  exit 1
fi
cp "$PROFILE_SRC" "$ROOT/.signing/Reisen.provisionprofile"
echo "Provisioning-Profil nach .signing/Reisen.provisionprofile kopiert." >&2
echo "macOS Automatic Signing ist eingerichtet (${MACOS_BUNDLE_ID})." >&2

if command -v gh >/dev/null 2>&1; then
  if gh secret set APPLE_TEAM_ID --body "$TEAM_ID" >/dev/null 2>&1; then
    echo "GitHub-Secret APPLE_TEAM_ID gesetzt." >&2
  else
    echo "Hinweis: GitHub-Secret APPLE_TEAM_ID konnte nicht gesetzt werden (gh-Rechte prüfen)." >&2
  fi
fi

echo "OK: Apple Developer Team ${TEAM_ID} ist für Reisen verdrahtet." >&2
echo "Container ${ICLOUD_CONTAINER} muss an beide App-IDs gebunden sein." >&2
