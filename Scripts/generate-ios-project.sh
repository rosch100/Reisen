#!/usr/bin/env bash
# Erzeugt das iOS Xcode-Projekt aus project.yml (XcodeGen SSOT).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Fehler: xcodegen nicht gefunden. Installieren mit: brew install xcodegen" >&2
  exit 1
fi

if [[ ! -f "$ROOT/project.yml" ]]; then
  echo "Fehler: project.yml fehlt im Repo-Root." >&2
  exit 1
fi

# Tests setzen REISEN_GITHUB_ISSUE_TOKEN_EMPTY=true (kein Live-Token).
# Produkt-Builds (ios-run / ios-archive) betten das Token ein, sofern vorhanden.
# App-Store-Archive setzt REISEN_REQUIRE_GITHUB_ISSUE_TOKEN=true.
bash "$ROOT/Scripts/embed-github-issue-token.sh"

xcodegen generate --spec "$ROOT/project.yml" --project "$ROOT"

if [[ ! -d "$ROOT/Reisen.xcodeproj" ]]; then
  echo "Fehler: Reisen.xcodeproj wurde nicht erzeugt." >&2
  exit 1
fi

echo "Sync LSApplicationQueriesSchemes aus ProviderNativeApp-SSOT …"
swift run --package-path "$ROOT" SyncIOSQuerySchemes "$ROOT/Apps/ReiseniOS/Info.plist"

# shellcheck source=apple-developer.sh
source "$ROOT/Scripts/apple-developer.sh"
if TEAM_ID="$(reisen_apple_team_id 2>/dev/null)"; then
  PBXPROJ="$ROOT/Reisen.xcodeproj/project.pbxproj"
  if ! grep -q "DEVELOPMENT_TEAM = ${TEAM_ID};" "$PBXPROJ"; then
    python3 - "$PBXPROJ" "$TEAM_ID" <<'PY'
import sys
path, team = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as f:
    content = f.read()
needle = "CODE_SIGN_STYLE = Automatic;"
replacement = f"CODE_SIGN_STYLE = Automatic;\n\t\t\t\tDEVELOPMENT_TEAM = {team};"
if needle not in content:
    raise SystemExit("CODE_SIGN_STYLE = Automatic; nicht in project.pbxproj gefunden")
content = content.replace(needle, replacement)
with open(path, "w", encoding="utf-8") as f:
    f.write(content)
PY
    echo "DEVELOPMENT_TEAM ${TEAM_ID} in project.pbxproj gesetzt." >&2
  fi
  if ! grep -q "DEVELOPMENT_TEAM = ${TEAM_ID};" "$PBXPROJ"; then
    echo "Fehler: DEVELOPMENT_TEAM ${TEAM_ID} konnte nicht in project.pbxproj gesetzt werden." >&2
    exit 1
  fi
else
  echo "Hinweis: Keine Team-ID konfiguriert — Signing in Xcode oder via APPLE_TEAM_ID setzen." >&2
fi

echo "OK: $ROOT/Reisen.xcodeproj"
