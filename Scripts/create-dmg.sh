#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF' >&2
Usage: Scripts/create-dmg.sh --app-path /abs/path/to/Reisen.app --dmg-path /abs/path/to/Reisen-0.1.dmg [--volname Reisen]

Creates a macOS-installable DMG (UDZO) following common HIG expectations:
- Copies the .app into the DMG root
- Adds an `Applications` symlink to /Applications
- Adds `.VolumeIcon.icns` so Finder can show the volume icon (layout positioning is Finder-dependent).
EOF
}

app_path=""
dmg_path=""
volname="Reisen"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-path)
      app_path="${2:-}"
      shift 2
      ;;
    --dmg-path)
      dmg_path="${2:-}"
      shift 2
      ;;
    --volname)
      volname="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Fehler: Unbekanntes Argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ -z "$app_path" || -z "$dmg_path" ]]; then
  echo "Fehler: --app-path und --dmg-path sind erforderlich." >&2
  usage
  exit 2
fi

if [[ ! -d "$app_path" || "${app_path%.app}" == "$app_path" ]]; then
  echo "Fehler: --app-path muss ein .app Bundle sein: $app_path" >&2
  exit 1
fi

if [[ -z "$dmg_path" || "$dmg_path" == */ ]]; then
  echo "Fehler: --dmg-path ist kein Dateipfad: $dmg_path" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ ! -f "$ROOT/Resources/AppIcon.icns" ]]; then
  echo "Fehler: Missing Volume Icon: Resources/AppIcon.icns" >&2
  exit 1
fi

mkdir -p "$(dirname "$dmg_path")"
rm -f "$dmg_path"

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir" >/dev/null 2>&1 || true
}
trap cleanup EXIT

srcdir="$tmpdir/dmg-src"
mkdir -p "$srcdir"

app_basename="$(basename "$app_path")" # e.g. Reisen.app
ditto "$app_path" "$srcdir/$app_basename"

ln -s /Applications "$srcdir/Applications"

# Volume icon: Finder will use .VolumeIcon.icns (layout is applied by Finder when mounting).
cp "$ROOT/Resources/AppIcon.icns" "$srcdir/.VolumeIcon.icns"

hdiutil create \
  -volname "$volname" \
  -fs HFS+ \
  -srcfolder "$srcdir" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -ov "$dmg_path" >/dev/null

printf '%s\n' "$dmg_path"

