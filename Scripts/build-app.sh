#!/usr/bin/env bash
# Baut Voyenna als echtes .app-Bundle (Dock-Icon, Tastatur/Menü, Berechtigungsdialoge).
# SPM-Target bleibt `Reisen`; Produkt-/Binary-Name ist `Voyenna` (CFBundleExecutable).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_PRODUCT_NAME="Voyenna"

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

if [[ "$CONFIG" == "release" && "${GITHUB_ACTIONS:-}" == "true" ]]; then
  export REISEN_REQUIRE_GITHUB_ISSUE_TOKEN=true
fi
unset REISEN_GITHUB_ISSUE_TOKEN_EMPTY
bash "$ROOT/Scripts/embed-github-issue-token.sh"

swift build -c "$CONFIG" >/dev/null

BIN="$ROOT/.build/$CONFIG/$APP_PRODUCT_NAME"
if [[ ! -x "$BIN" ]]; then
  BIN="$(find "$ROOT/.build" -path "*/Products/$OUT_CONFIG/$APP_PRODUCT_NAME" -type f | head -1)"
fi
if [[ -z "${BIN}" || ! -x "$BIN" ]]; then
  echo "Fehler: $APP_PRODUCT_NAME-Binary nicht gefunden (Config $CONFIG / $OUT_CONFIG)." >&2
  exit 1
fi

# SwiftPM Resource-Bundles (Bundle.module) müssen im .app liegen; sonst fatalError beim Start
# (z. B. L10n → Reisen_ReisenDomain.bundle, ProviderLogo → Reisen_Reisen.bundle).
RUNTIME_SPM_BUNDLES=(
  Reisen_Reisen.bundle
  Reisen_ReisenDomain.bundle
)

find_spm_resource_bundle() {
  local bundle_name="$1"
  local candidate
  for candidate in \
    "$(dirname "$BIN")/$bundle_name" \
    "$ROOT/.build/$CONFIG/$bundle_name" \
    "$ROOT/.build/out/Products/$OUT_CONFIG/$bundle_name"
  do
    if [[ -d "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  find "$ROOT/.build" -type d -name "$bundle_name" ! -path '*Tests*' 2>/dev/null | head -1
}

copy_spm_resource_bundles() {
  local bundle_name source
  for bundle_name in "${RUNTIME_SPM_BUNDLES[@]}"; do
    source="$(find_spm_resource_bundle "$bundle_name")"
    if [[ -z "$source" || ! -d "$source" ]]; then
      echo "Fehler: $bundle_name nicht gefunden (SwiftPM-Resources)." >&2
      exit 1
    fi
    cp -R "$source" "$RESOURCES/$bundle_name"
    cp -R "$source" "$MACOS/$bundle_name"
  done
}

sign_spm_resource_bundles() {
  local bundle_name
  for bundle_name in "${RUNTIME_SPM_BUNDLES[@]}"; do
    codesign --force --sign "$SIGN_IDENTITY" "$RESOURCES/$bundle_name"
    codesign --force --sign "$SIGN_IDENTITY" "$MACOS/$bundle_name"
  done
}

APP="$ROOT/.build/${APP_PRODUCT_NAME}.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
EXECUTABLE="$MACOS/$APP_PRODUCT_NAME"

# Laufende Instanz dieses Bundle-Pfads vor rm -rf beenden. Sonst zeigt Bundle.main
# weiter auf gelöschte Resources → ProviderLogo fällt auf questionmark.circle zurück
# (SVGs/L10n nicht mehr ladbar, Prozess bleibt aber am Leben).
if [[ -d "$APP" ]]; then
  while read -r pid; do
    [[ -n "${pid:-}" ]] || continue
    kill "$pid" 2>/dev/null || true
  done < <(pgrep -f "$EXECUTABLE" || true)
  # Kurz warten, bis der Prozess die Dateien freigibt (kein hangendes unlink).
  for _ in 1 2 3 4 5; do
    pgrep -f "$EXECUTABLE" >/dev/null 2>&1 || break
    sleep 0.1
  done
fi

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES"

cp "$BIN" "$EXECUTABLE"
chmod +x "$EXECUTABLE"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$RESOURCES/AppIcon.icns"
ENTITLEMENTS="$ROOT/Resources/Reisen.entitlements"
if [[ ! -f "$ENTITLEMENTS" ]]; then
  echo "Fehler: Entitlements fehlen: $ENTITLEMENTS" >&2
  exit 1
fi

copy_spm_resource_bundles

# Flat-SVGs in App-Resources → Bundle.main.url(forResource:) als Fallback ohne Bundle.module.
LOGO_DIR="$ROOT/Sources/Reisen/Resources/ProviderLogos"
if [[ -d "$LOGO_DIR" ]]; then
  cp "$LOGO_DIR"/*.svg "$RESOURCES/" 2>/dev/null || true
fi

PROFILE="$(reisen_provision_profile_path "$ROOT" || true)"
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
  echo "Hinweis: Kein Reisen.provisionprofile (lokal oder Primär-Checkout) — ad-hoc ohne iCloud-Entitlements." >&2
  echo "  Team-Signing: bash ./Scripts/setup-apple-developer.sh" >&2
fi
cp "$SIGN_ENTITLEMENTS" "$CONTENTS/Reisen.entitlements"

sign_spm_resource_bundles
codesign --force --deep --sign "$SIGN_IDENTITY" --entitlements "$SIGN_ENTITLEMENTS" "$APP"

printf '%s\n' "$APP"
