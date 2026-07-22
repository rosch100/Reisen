#!/usr/bin/env bash
# Baut Reisen als echtes .app-Bundle (Dock-Icon, Tastatur/Menü, Berechtigungsdialoge).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

swift build -c debug >/dev/null

BIN="$ROOT/.build/debug/Reisen"
if [[ ! -x "$BIN" ]]; then
  BIN="$(find "$ROOT/.build" -path '*/Products/Debug/Reisen' -type f | head -1)"
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
  "$ROOT/.build/debug/$BUNDLE_NAME" \
  "$ROOT/.build/out/Products/Debug/$BUNDLE_NAME"
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
