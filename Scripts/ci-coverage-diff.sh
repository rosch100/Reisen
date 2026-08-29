#!/usr/bin/env bash
# Diff-scoped llvm-cov vs merge-base. Swift CRAP-Proxy: lines% + regions.count.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

GATE="${REISEN_CRAP_GATE:-5}"
BASE="${1:-}"
if [[ -z "$BASE" ]]; then
  BASE="$(git merge-base HEAD feat/f06-paste-import 2>/dev/null || git merge-base HEAD origin/master)"
fi

export REISEN_GITHUB_ISSUE_TOKEN_EMPTY=true
unset REISEN_EMBED_GITHUB_ISSUE_TOKEN
unset REISEN_REQUIRE_GITHUB_ISSUE_TOKEN
bash "$ROOT/Scripts/embed-github-issue-token.sh"

FILTER_ARGS=()
if [[ "${REISEN_COVERAGE_FILTER:-}" != "" ]]; then
  FILTER_ARGS+=(--filter "$REISEN_COVERAGE_FILTER")
fi

swift test --enable-code-coverage "${FILTER_ARGS[@]}"

CODECOV="$ROOT/.build/out/Products/Debug/codecov"
PROFDATA="$CODECOV/merged.profdata"
EXPORT_JSON="$CODECOV/diff-export.json"

shopt -s nullglob
RAW=("$CODECOV"/*.profraw)
if [[ ${#RAW[@]} -eq 0 ]]; then
  echo "Fehler: keine .profraw unter $CODECOV" >&2
  exit 1
fi
xcrun llvm-profdata merge -sparse "${RAW[@]}" -o "$PROFDATA"

OBJECTS=()
for tests in ReisenDomainTests ReisenAppCoreTests ReisenSharedUITests; do
  bin="$ROOT/.build/out/Products/Debug/${tests}.xctest/Contents/MacOS/${tests}"
  if [[ -x "$bin" ]]; then
    OBJECTS+=("$bin")
  fi
done
if [[ ${#OBJECTS[@]} -eq 0 ]]; then
  echo "Fehler: keine Test-Binaries für llvm-cov" >&2
  exit 1
fi

COV_ARGS=("${OBJECTS[0]}" -instr-profile="$PROFDATA")
for extra in "${OBJECTS[@]:1}"; do
  COV_ARGS+=(-object "$extra")
done
xcrun llvm-cov export -format=text "${COV_ARGS[@]}" >"$EXPORT_JSON"

DIFF_SWIFT=()
while IFS= read -r line; do
  [[ -n "$line" ]] && DIFF_SWIFT+=("$line")
done < <(
  git diff --name-only "$BASE"...HEAD -- 'Sources/**/*.swift' \
    | grep -v '/App/' \
    | grep -v '^Apps/' \
    | grep -v 'Localization/L10nKey.swift' \
    | grep -v 'PasteImportCandidateSheet.swift' \
    | grep -v 'PasteImportCandidateList.swift' \
    || true
)

if [[ ${#DIFF_SWIFT[@]} -eq 0 ]]; then
  echo "OK: keine Sources-Swift-Dateien im Diff vs $BASE (ohne App-Host)."
  exit 0
fi

python3 "$ROOT/Scripts/coverage-diff.py" "$EXPORT_JSON" "$GATE" "${DIFF_SWIFT[@]}"
