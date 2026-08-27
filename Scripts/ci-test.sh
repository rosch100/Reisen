#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SKIP_BUILD="false"
WITH_IOS_RELEASE_CHECK="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-build)
      SKIP_BUILD="true"
      shift
      ;;
    --no-skip-build)
      SKIP_BUILD="false"
      shift
      ;;
    --with-ios-release-check)
      WITH_IOS_RELEASE_CHECK="true"
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [--skip-build|--no-skip-build] [--with-ios-release-check]" >&2
      exit 0
      ;;
    *)
      echo "Fehler: Unbekanntes Argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ "${CI:-}" == "true" || "${GITHUB_ACTIONS:-}" == "true" ]]; then
  SKIP_BUILD="true"
fi

GENERATED_REL="Sources/ReisenAppCore/GitHubIssues/GitHubIssueToken.generated.swift"
STUB="$ROOT/Sources/ReisenAppCore/GitHubIssues/GitHubIssueToken.generated.swift.stub"
if git ls-files --error-unmatch "$GENERATED_REL" >/dev/null 2>&1; then
  echo "Fehler: GitHubIssueToken.generated.swift darf nicht versioniert sein (nur .stub)." >&2
  exit 1
fi
if ! grep -q 'static let bytes: \[UInt8\] = \[\]' "$STUB"; then
  echo "Fehler: GitHubIssueToken.generated.swift.stub muss leere bytes enthalten." >&2
  exit 1
fi
if ! grep -q 'static let key: \[UInt8\] = \[\]' "$STUB"; then
  echo "Fehler: GitHubIssueToken.generated.swift.stub muss leeren XOR-Key enthalten." >&2
  exit 1
fi
if grep -q '0x' "$STUB"; then
  echo "Fehler: GitHubIssueToken.generated.swift.stub darf keine XOR-Bytes enthalten." >&2
  exit 1
fi
if grep -q 'REISEN_GITHUB_ISSUE_TOKEN_EMPTY=true' "$ROOT/Scripts/ios-archive-appstore.sh"; then
  echo "Fehler: App-Store-Archive darf REISEN_GITHUB_ISSUE_TOKEN_EMPTY=true nicht setzen." >&2
  exit 1
fi
if ! grep -q 'REISEN_REQUIRE_GITHUB_ISSUE_TOKEN=true' "$ROOT/Scripts/ios-archive-appstore.sh"; then
  echo "Fehler: App-Store-Archive muss REISEN_REQUIRE_GITHUB_ISSUE_TOKEN=true setzen." >&2
  exit 1
fi
if ! grep -q 'REISEN_EMBED_GITHUB_ISSUE_TOKEN=true' "$ROOT/Scripts/ios-archive-appstore.sh"; then
  echo "Fehler: App-Store-Archive muss REISEN_EMBED_GITHUB_ISSUE_TOKEN=true setzen." >&2
  exit 1
fi
if grep -q 'REISEN_GITHUB_ISSUE_TOKEN_EMPTY=true' "$ROOT/Scripts/ios-archive-adhoc.sh"; then
  echo "Fehler: Ad-hoc-Archive darf REISEN_GITHUB_ISSUE_TOKEN_EMPTY=true nicht setzen." >&2
  exit 1
fi
if ! grep -q 'REISEN_EMBED_GITHUB_ISSUE_TOKEN=true' "$ROOT/Scripts/ios-archive-adhoc.sh"; then
  echo "Fehler: Ad-hoc-Archive muss REISEN_EMBED_GITHUB_ISSUE_TOKEN=true setzen." >&2
  exit 1
fi
if ! grep -q 'REISEN_REQUIRE_GITHUB_ISSUE_TOKEN=true' "$ROOT/Scripts/ios-archive-adhoc.sh"; then
  echo "Fehler: Ad-hoc-Archive muss REISEN_REQUIRE_GITHUB_ISSUE_TOKEN=true setzen." >&2
  exit 1
fi
if ! grep -q -- '--mode store --ipa' "$ROOT/Scripts/ios-archive-appstore.sh"; then
  echo "Fehler: App-Store-Archive muss das exportierte IPA store-isolieren (--ipa)." >&2
  exit 1
fi
if ! grep -q 'ios-archive-appstore.sh' "$ROOT/.github/workflows/app-store-check.yml"; then
  echo "Fehler: App Store Check muss Scripts/ios-archive-appstore.sh verwenden (nur Store-Target)." >&2
  exit 1
fi
if grep -q 'ios-archive-adhoc.sh' "$ROOT/.github/workflows/app-store-check.yml"; then
  echo "Fehler: App Store Check darf das Private-Archive nicht bauen oder scannen." >&2
  exit 1
fi
WF="$ROOT/.github/workflows/app-store-check.yml"
if grep -A8 '^    name: Archive Store IPA' "$WF" | grep -qE 'needs: (preflight|appcompliance-secrets)'; then
  echo "Fehler: Archive Store IPA darf nicht an AppCompliance-Secrets hängen." >&2
  exit 1
fi
if ! awk '
  $0 ~ /^  scan:/ { in_scan=1; next }
  in_scan && $0 ~ /^  [a-zA-Z]/ { exit found ? 0 : 1 }
  in_scan && $0 ~ /outputs\.enabled/ { found=1 }
  END { exit found ? 0 : 1 }
' "$WF"; then
  echo "Fehler: AppCompliance-Scan muss per Job-Output enabled skippen (kein secrets in job if:)." >&2
  exit 1
fi
if awk '
  $0 ~ /^  appcompliance-secrets:/ { in_secrets=1; next }
  in_secrets && $0 ~ /^  [a-zA-Z]/ { exit found_exit ? 0 : 1 }
  in_secrets && $0 ~ /exit 1/ { found_exit=1 }
  END { exit found_exit ? 0 : 1 }
' "$WF"; then
  echo "Fehler: AppCompliance-Secrets-Job darf fehlende Secrets nicht mit exit 1 abbrechen." >&2
  exit 1
fi
if ! grep -q 'REISEN_GITHUB_ISSUES_TOKEN_BASE64: ${{ secrets.REISEN_GITHUB_ISSUES_TOKEN_BASE64 }}' "$WF"; then
  echo "Fehler: App Store Check muss REISEN_GITHUB_ISSUES_TOKEN_BASE64 an das Store-Archive durchreichen." >&2
  exit 1
fi
if grep -q 'REISEN_FEEDBACK_GMAIL_APP_PASSWORD' "$ROOT/.github/workflows/gmail-feedback-ingress.yml"; then
  echo "Fehler: Gmail-Ingress darf kein App-Passwort mehr nutzen." >&2
  exit 1
fi
if ! grep -q 'REISEN_GMAIL_OAUTH_REFRESH_TOKEN' "$ROOT/.github/workflows/gmail-feedback-ingress.yml"; then
  echo "Fehler: Gmail-Ingress muss REISEN_GMAIL_OAUTH_REFRESH_TOKEN setzen." >&2
  exit 1
fi
REISEN_GITHUB_ISSUE_TOKEN_EMPTY=true bash "$ROOT/Scripts/embed-github-issue-token.sh"

python3 -m unittest discover -s "$ROOT/Scripts/tests/ingest-gmail-feedback" -v

if [[ "$SKIP_BUILD" == "true" ]]; then
  swift test -v --skip-build
else
  swift test -v
fi

if [[ "$WITH_IOS_RELEASE_CHECK" == "true" ]]; then
  env CI=true REISEN_CLOUDKIT=0 bash "$ROOT/Scripts/ios-build-release-check.sh"
fi

