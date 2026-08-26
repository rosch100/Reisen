#!/usr/bin/env bash
# Baut Reisen als echtes .app-Bundle (Dock-Icon, Tastatur/Menü, Berechtigungsdialoge).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# shellcheck source=apple-developer.sh
source "$ROOT/Scripts/apple-developer.sh"

CONFIG="debug"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --configuration)
      CONFIG="${2:-}"
      shift 2
      ;;
    -c|--config)
      CONFIG="${2:-}"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 [--configuration debug|release]" >&2
      exit 0
      ;;
    *)
      echo "Fehler: Unbekanntes Argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ "$CONFIG" != "debug" && "$CONFIG" != "release" ]]; then
  echo "Fehler: --configuration muss 'debug' oder 'release' sein (bekommen: $CONFIG)." >&2
  exit 2
fi

OUT_CONFIG="Debug"
if [[ "$CONFIG" == "release" ]]; then
  OUT_CONFIG="Release"
fi

swift build -c "$CONFIG" >/dev/null

BIN="$ROOT/.build/$CONFIG/Reisen"
if [[ ! -x "$BIN" ]]; then
  BIN="$(find "$ROOT/.build" -path '*/Products/Debug/Reisen' -type f | head -1)"
  if [[ "$CONFIG" == "release" && ! -x "$BIN" ]]; then
    BIN="$(find "$ROOT/.build" -path '*/Products/Release/Reisen' -type f | head -1)"
  fi
fi
if [[ -z "${BIN}" || ! -x "$BIN" ]]; then
  echo "Fehler: Reisen-Binary nicht gefunden." >&2
  exit 1
fi

# SwiftPM Resource-Bundle (Bundle.module → Reisen_Reisen.bundle) muss neben den
# App-Resources liegen, sonst crasht ProviderLogo beim Start mit fatalError.
BUNDLE_NAME="Reisen_Reisen.bundle"
RESOURCE_BUNDLE=""
for candidate in \
  "$(dirname "$BIN")/$BUNDLE_NAME" \
  "$ROOT/.build/$CONFIG/$BUNDLE_NAME" \
  "$ROOT/.build/out/Products/$OUT_CONFIG/$BUNDLE_NAME"
do
  if [[ -d "$candidate" ]]; then
    RESOURCE_BUNDLE="$candidate"
    break
  fi
done
if [[ -z "$RESOURCE_BUNDLE" ]]; then
  RESOURCE_BUNDLE="$(find "$ROOT/.build" -type d -name "$BUNDLE_NAME" | head -1 || true)"
fi
if [[ -z "$RESOURCE_BUNDLE" || ! -d "$RESOURCE_BUNDLE" ]]; then
  echo "Fehler: $BUNDLE_NAME nicht gefunden (SwiftPM-Resources)." >&2
  exit 1
fi

APP="$ROOT/.build/Reisen.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES"

cp "$BIN" "$MACOS/Reisen"
chmod +x "$MACOS/Reisen"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$RESOURCES/AppIcon.icns"
ENTITLEMENTS="$ROOT/Resources/Reisen.entitlements"
if [[ ! -f "$ENTITLEMENTS" ]]; then
  echo "Fehler: Entitlements fehlen: $ENTITLEMENTS" >&2
  exit 1
fi

# SPM Bundle.module-Pfad: Contents/Resources/Reisen_Reisen.bundle
cp -R "$RESOURCE_BUNDLE" "$RESOURCES/$BUNDLE_NAME"
# Zusätzlich neben dem Binary (CLI-/Xcode-ähnliche Auflösung über bundleURL.deletingLastPathComponent).
cp -R "$RESOURCE_BUNDLE" "$MACOS/$BUNDLE_NAME"

# Flat-SVGs in App-Resources → Bundle.main.url(forResource:) als Fallback ohne Bundle.module.
LOGO_DIR="$ROOT/Sources/Reisen/Resources/ProviderLogos"
if [[ -d "$LOGO_DIR" ]]; then
  cp "$LOGO_DIR"/*.svg "$RESOURCES/" 2>/dev/null || true
fi

PROFILE="$ROOT/.signing/Reisen.provisionprofile"
MERGED_ENTITLEMENTS=""
cleanup_merged_entitlements() {
  if [[ -n "${MERGED_ENTITLEMENTS:-}" ]]; then
    rm -f "$MERGED_ENTITLEMENTS"
  fi
}
trap cleanup_merged_entitlements EXIT

# Restricted Entitlements (iCloud) auf Ad-hoc → launchd POSIX 163.
strip_icloud_entitlements() {
  local src="$1"
  local dest="$2"
  cp "$src" "$dest"
  /usr/libexec/PlistBuddy -c 'Delete :com.apple.developer.icloud-container-identifiers' "$dest" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c 'Delete :com.apple.developer.icloud-services' "$dest" >/dev/null 2>&1 || true
}

# CI: explizit ad-hoc. Lokal mit Profil: Apple Development (CloudKit).
# Ohne Profil kein Apple Development — launchd lehnt das mit POSIX 163 ab.
if [[ "${CI:-}" == "true" || "${GITHUB_ACTIONS:-}" == "true" ]]; then
  SIGN_IDENTITY="-"
  MERGED_ENTITLEMENTS="$(mktemp)"
  strip_icloud_entitlements "$ENTITLEMENTS" "$MERGED_ENTITLEMENTS"
  SIGN_ENTITLEMENTS="$MERGED_ENTITLEMENTS"
  echo "Codesign Identity: ad-hoc (CI)" >&2
elif [[ -f "$PROFILE" ]]; then
  SIGN_IDENTITY="$(reisen_apple_development_identity)"
  TEAM_ID="$(reisen_apple_team_id)"
  BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$CONTENTS/Info.plist")"
  MERGED_ENTITLEMENTS="$(mktemp)"
  cp "$ENTITLEMENTS" "$MERGED_ENTITLEMENTS"
  /usr/libexec/PlistBuddy -c "Add :com.apple.application-identifier string ${TEAM_ID}.${BUNDLE_ID}" "$MERGED_ENTITLEMENTS"
  /usr/libexec/PlistBuddy -c "Add :com.apple.developer.team-identifier string ${TEAM_ID}" "$MERGED_ENTITLEMENTS"
  # Profil listet erlaubte Umgebungen als Array; die Signatur braucht genau einen Wert.
  # Launchd prüft gegen das Profil (`Development`/`Production`); CloudKit erwartet denselben Token.
  /usr/libexec/PlistBuddy -c 'Delete :com.apple.developer.icloud-container-environment' "$MERGED_ENTITLEMENTS" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c 'Add :com.apple.developer.icloud-container-environment string Development' "$MERGED_ENTITLEMENTS"
  SIGN_ENTITLEMENTS="$MERGED_ENTITLEMENTS"
  cp "$PROFILE" "$CONTENTS/embedded.provisionprofile"
  echo "Codesign Identity: $SIGN_IDENTITY (Provisioning-Profil)" >&2
else
  SIGN_IDENTITY="-"
  MERGED_ENTITLEMENTS="$(mktemp)"
  strip_icloud_entitlements "$ENTITLEMENTS" "$MERGED_ENTITLEMENTS"
  SIGN_ENTITLEMENTS="$MERGED_ENTITLEMENTS"
  echo "Hinweis: Kein .signing/Reisen.provisionprofile — ad-hoc ohne iCloud-Entitlements." >&2
  echo "  Team-Signing: bash ./Scripts/setup-apple-developer.sh" >&2
fi
cp "$SIGN_ENTITLEMENTS" "$CONTENTS/Reisen.entitlements"

codesign --force --sign "$SIGN_IDENTITY" "$RESOURCES/$BUNDLE_NAME"
codesign --force --sign "$SIGN_IDENTITY" "$MACOS/$BUNDLE_NAME"
codesign --force --deep --sign "$SIGN_IDENTITY" --entitlements "$SIGN_ENTITLEMENTS" "$APP"

printf '%s\n' "$APP"
