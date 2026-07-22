#!/usr/bin/env bash
# Baut Reisen als echtes .app-Bundle (Dock-Icon, Tastatur/Menü, Berechtigungsdialoge).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

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

# SPM Bundle.module-Pfad: Contents/Resources/Reisen_Reisen.bundle
cp -R "$RESOURCE_BUNDLE" "$RESOURCES/$BUNDLE_NAME"
# Zusätzlich neben dem Binary (CLI-/Xcode-ähnliche Auflösung über bundleURL.deletingLastPathComponent).
cp -R "$RESOURCE_BUNDLE" "$MACOS/$BUNDLE_NAME"

# Flat-SVGs in App-Resources → Bundle.main.url(forResource:) als Fallback ohne Bundle.module.
LOGO_DIR="$ROOT/Sources/Reisen/Resources/ProviderLogos"
if [[ -d "$LOGO_DIR" ]]; then
  cp "$LOGO_DIR"/*.svg "$RESOURCES/" 2>/dev/null || true
fi

# Codesign ad-hoc, damit Gatekeeper/TCC die App als Bundle akzeptiert.
# Nested resource bundle zuerst einzeln, dann App (deep).
codesign --force --sign - "$RESOURCES/$BUNDLE_NAME" >/dev/null 2>&1 || true
codesign --force --sign - "$MACOS/$BUNDLE_NAME" >/dev/null 2>&1 || true
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

printf '%s\n' "$APP"
