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
python3 - "$WF" <<'PY'
import re
import sys
from pathlib import Path

FORBIDDEN_ARCHIVE_NEEDS = {"preflight", "appcompliance-secrets"}


def job_top_fields(text: str, job_id: str) -> dict[str, object]:
    """Job-level needs/if only (indent 4), not steps."""
    lines = text.splitlines()
    in_jobs = False
    current: str | None = None
    fields: dict[str, object] = {}
    collecting_needs = False
    found = False
    job_re = re.compile(r"^  ([A-Za-z0-9_-]+):\s*$")
    field_re = re.compile(r"^    ([A-Za-z0-9_-]+):\s*(.*)$")
    list_item_re = re.compile(r"^      -\s+(\S+)\s*$")
    for line in lines:
        if line.startswith("jobs:"):
            in_jobs = True
            continue
        if not in_jobs:
            continue
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        job_match = job_re.match(line)
        if job_match:
            collecting_needs = False
            if found:
                break
            current = job_match.group(1)
            if current == job_id:
                found = True
                fields = {}
            continue
        if current != job_id:
            continue
        field_match = field_re.match(line)
        if field_match:
            key, rest = field_match.group(1), field_match.group(2).strip()
            collecting_needs = False
            if key == "needs":
                if rest.startswith("[") and rest.endswith("]"):
                    inner = rest[1:-1].strip()
                    fields["needs"] = [part.strip() for part in inner.split(",") if part.strip()]
                elif rest:
                    fields["needs"] = [rest]
                else:
                    fields["needs"] = []
                    collecting_needs = True
            elif key == "if":
                fields["if"] = rest
            continue
        if collecting_needs:
            item = list_item_re.match(line)
            if item:
                needs = fields.setdefault("needs", [])
                if isinstance(needs, list):
                    needs.append(item.group(1))
                continue
            collecting_needs = False
    if not found:
        raise SystemExit(f"Fehler: Job {job_id} fehlt in app-store-check.yml.")
    return fields


def needs_ids(fields: dict[str, object]) -> list[str]:
    raw = fields.get("needs", [])
    if raw is None:
        return []
    if isinstance(raw, str):
        return [raw]
    if isinstance(raw, list):
        return [str(item) for item in raw]
    raise SystemExit("Fehler: needs hat unerwarteten Typ.")


scalar = """
jobs:
  archive:
    needs: preflight
    runs-on: ubuntu-latest
"""
listed = """
jobs:
  archive:
    needs:
      - appcompliance-secrets
      - other
    runs-on: ubuntu-latest
"""
flow = """
jobs:
  archive:
    needs: [appcompliance-secrets, other]
    runs-on: ubuntu-latest
"""
if "preflight" not in needs_ids(job_top_fields(scalar, "archive")):
    raise SystemExit("Fehler: Self-Check scalar needs fehlgeschlagen.")
if "appcompliance-secrets" not in needs_ids(job_top_fields(listed, "archive")):
    raise SystemExit("Fehler: Self-Check list needs fehlgeschlagen.")
if "appcompliance-secrets" not in needs_ids(job_top_fields(flow, "archive")):
    raise SystemExit("Fehler: Self-Check flow needs fehlgeschlagen.")
secret_if = """
jobs:
  scan:
    if: ${{ secrets.APPCOMPLIANCE_TOKEN != '' }}
    runs-on: ubuntu-latest
"""
ok_if = """
jobs:
  scan:
    if: needs.appcompliance-secrets.outputs.enabled == 'true'
    runs-on: ubuntu-latest
"""
bad_if = str(job_top_fields(secret_if, "scan").get("if", ""))
good_if = str(job_top_fields(ok_if, "scan").get("if", ""))
if "outputs.enabled" not in good_if:
    raise SystemExit("Fehler: Self-Check scan.if outputs.enabled fehlgeschlagen.")
if not re.search(r"(?:^|[^A-Za-z0-9_-])secrets\.", bad_if):
    raise SystemExit("Fehler: Self-Check scan.if secrets-Condition fehlgeschlagen.")
if re.search(r"(?:^|[^A-Za-z0-9_-])secrets\.", good_if):
    raise SystemExit("Fehler: Self-Check scan.if false-positive secrets.")

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
archive = job_top_fields(text, "archive")
blocked = FORBIDDEN_ARCHIVE_NEEDS.intersection(needs_ids(archive))
if blocked:
    print(
        "Fehler: Archive Store IPA darf nicht an AppCompliance-Secrets hängen "
        f"(needs enthält {sorted(blocked)}).",
        file=sys.stderr,
    )
    raise SystemExit(1)

scan = job_top_fields(text, "scan")
scan_if = str(scan.get("if", ""))
if "outputs.enabled" not in scan_if:
    print(
        "Fehler: AppCompliance-Scan muss per Job-Output enabled skippen "
        "(scan.if ohne outputs.enabled).",
        file=sys.stderr,
    )
    raise SystemExit(1)
if re.search(r"(?:^|[^A-Za-z0-9_-])secrets\.", scan_if):
    print(
        "Fehler: scan.if darf keine secrets-Condition nutzen (actionlint: secrets nicht in job if:).",
        file=sys.stderr,
    )
    raise SystemExit(1)
PY
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
if ! grep -q 'APP_STORE_CONNECT_API_KEY_BASE64: ${{ secrets.APP_STORE_CONNECT_API_KEY_BASE64 }}' "$WF"; then
  echo "Fehler: App Store Check muss den App-Store-Connect-API-Key an das Store-Archive durchreichen." >&2
  exit 1
fi
if ! grep -q 'reisen_xcodebuild_asc_auth_args' "$ROOT/Scripts/ios-archive-appstore.sh"; then
  echo "Fehler: App-Store-Archive muss xcodebuild mit App-Store-Connect-API-Key authentifizieren." >&2
  exit 1
fi
(
  # shellcheck source=apple-developer.sh
  source "$ROOT/Scripts/apple-developer.sh"
  APP_STORE_CONNECT_API_KEY_KEY_ID="TESTKEYID"
  APP_STORE_CONNECT_API_KEY_ISSUER="00000000-0000-0000-0000-000000000000"
  APP_STORE_CONNECT_API_KEY_BASE64="$(printf 'reisen-asc-key-fixture' | base64)"
  unset APP_STORE_CONNECT_API_KEY_PATH
  auth_out="$(reisen_xcodebuild_asc_auth_args)"
  if ! grep -q -- '-authenticationKeyPath' <<<"$auth_out"; then
    echo "Fehler: reisen_xcodebuild_asc_auth_args muss BASE64 in einen Key-Pfad materialisieren." >&2
    exit 1
  fi
)
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

