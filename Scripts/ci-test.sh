#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SKIP_BUILD="false"

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
    -h|--help)
      echo "Usage: $0 [--skip-build|--no-skip-build]" >&2
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
REISEN_GITHUB_ISSUE_TOKEN_EMPTY=true bash "$ROOT/Scripts/embed-github-issue-token.sh"

if [[ "$SKIP_BUILD" == "true" ]]; then
  swift test -v --skip-build
else
  swift test -v
fi

