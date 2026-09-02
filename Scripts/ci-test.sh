#!/usr/bin/env bash
set -euo pipefail

REISEN_CI_T0="$(date +%s)"
trap 'echo "reisen-ci-duration: script=ci-test.sh seconds=$(( $(date +%s) - REISEN_CI_T0 ))" >&2' EXIT

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
python3 "$ROOT/Scripts/tests/check-app-store-check-workflow.py" "$ROOT/.github/workflows/app-store-check.yml"
if ! grep -q 'altool --validate-app' "$ROOT/Scripts/ios-validate-appstore.sh"; then
  echo "Fehler: ios-validate-appstore.sh muss xcrun altool --validate-app aufrufen." >&2
  exit 1
fi
if ! grep -q 'API_PRIVATE_KEYS_DIR' "$ROOT/Scripts/ios-validate-appstore.sh"; then
  echo "Fehler: ios-validate-appstore.sh muss API_PRIVATE_KEYS_DIR für altool setzen." >&2
  exit 1
fi
if ! grep -q 'APP_STORE_CONNECT_APPLE_ID' "$ROOT/Scripts/ios-validate-appstore.sh"; then
  echo "Fehler: ios-validate-appstore.sh muss optionales --apple-id über APP_STORE_CONNECT_APPLE_ID unterstützen." >&2
  exit 1
fi
if ! grep -q 'Unable to find Apple ID for Bundle ID' "$ROOT/Scripts/ios-validate-appstore.sh"; then
  echo "Fehler: ios-validate-appstore.sh muss fehlenden ASC-App-Eintrag erklären." >&2
  exit 1
fi
if ! grep -q '90534' "$ROOT/Scripts/ios-validate-appstore.sh"; then
  echo "Fehler: ios-validate-appstore.sh muss ITMS 90534 (Beta-Xcode) erklären." >&2
  exit 1
fi
if grep -q 'AUTH_OUT="$(reisen_xcodebuild_asc_auth_args)"' "$ROOT/Scripts/ios-validate-appstore.sh"; then
  echo "Fehler: reisen_xcodebuild_asc_auth_args darf nicht in Command-Substitution laufen (Subshell löscht den Temp-Key)." >&2
  exit 1
fi
if bash "$ROOT/Scripts/ios-validate-appstore.sh" >/dev/null 2>&1; then
  echo "Fehler: ios-validate-appstore.sh muss ohne IPA-Pfad abbrechen." >&2
  exit 1
fi
_reisen_missing_ipa="$(mktemp "${TMPDIR:-/tmp}/ReiseniOSMissing.XXXXXX.ipa")"
rm -f "$_reisen_missing_ipa"
_reisen_missing_ipa_err="$(
  bash "$ROOT/Scripts/ios-validate-appstore.sh" "$_reisen_missing_ipa" 2>&1 || true
)"
if [[ "$_reisen_missing_ipa_err" != *"ios-archive-appstore.sh"* ]]; then
  echo "Fehler: fehlendes Store-IPA muss auf ios-archive-appstore.sh hinweisen." >&2
  exit 1
fi
_reisen_private_ipa="$(mktemp "${TMPDIR:-/tmp}/ReiseniOSPrivate.XXXXXX.ipa")"
if bash "$ROOT/Scripts/ios-validate-appstore.sh" "$_reisen_private_ipa" >/dev/null 2>&1; then
  rm -f "$_reisen_private_ipa"
  echo "Fehler: ios-validate-appstore.sh darf kein Private-IPA validieren." >&2
  exit 1
fi
rm -f "$_reisen_private_ipa"
python3 -m unittest "$ROOT/Scripts/tests/test_ios_validate_appstore_report.py" -v
python3 -m unittest "$ROOT/Scripts/tests/test_coverage_diff.py" -v
if ! grep -q 'reisen_xcodebuild_asc_auth_args' "$ROOT/Scripts/ios-archive-appstore.sh"; then
  echo "Fehler: App-Store-Archive muss xcodebuild mit App-Store-Connect-API-Key authentifizieren." >&2
  exit 1
fi
if grep -q 'AUTH_OUT="$(reisen_xcodebuild_asc_auth_args)"' "$ROOT/Scripts/ios-archive-appstore.sh"; then
  echo "Fehler: reisen_xcodebuild_asc_auth_args darf nicht in Command-Substitution laufen (Subshell löscht den Temp-Key)." >&2
  exit 1
fi
(
  # shellcheck source=apple-developer.sh
  source "$ROOT/Scripts/apple-developer.sh"
  _reisen_profile_local="$(mktemp -d "${TMPDIR:-/tmp}/reisen-profile-local.XXXXXX")"
  mkdir -p "$_reisen_profile_local/.signing"
  printf 'local-profile\n' >"$_reisen_profile_local/.signing/Reisen.provisionprofile"
  _reisen_got="$(reisen_provision_profile_path "$_reisen_profile_local")"
  if [[ "$_reisen_got" != "$_reisen_profile_local/.signing/Reisen.provisionprofile" ]]; then
    echo "Fehler: reisen_provision_profile_path muss \$ROOT/.signing/Reisen.provisionprofile bevorzugen." >&2
    rm -rf "$_reisen_profile_local"
    exit 1
  fi
  rm -rf "$_reisen_profile_local"

  _reisen_primary="$(mktemp -d "${TMPDIR:-/tmp}/reisen-profile-primary.XXXXXX")"
  git -C "$_reisen_primary" init -q
  git -C "$_reisen_primary" config user.email "test@example.com"
  git -C "$_reisen_primary" config user.name "Test"
  git -C "$_reisen_primary" config core.autocrlf false
  mkdir -p "$_reisen_primary/.signing"
  printf 'primary-profile\n' >"$_reisen_primary/.signing/Reisen.provisionprofile"
  printf 'init\n' >"$_reisen_primary/README"
  git -C "$_reisen_primary" add README
  git -C "$_reisen_primary" commit -qm init
  _reisen_wt="$(mktemp -d "${TMPDIR:-/tmp}/reisen-profile-wt.XXXXXX")"
  rmdir "$_reisen_wt"
  git -C "$_reisen_primary" worktree add -q "$_reisen_wt" HEAD
  _reisen_got="$(reisen_provision_profile_path "$_reisen_wt")"
  if [[ ! -f "$_reisen_got" ]] || [[ "$(cat "$_reisen_got")" != "primary-profile" ]]; then
    echo "Fehler: reisen_provision_profile_path muss in Worktrees das Profil des Primär-Checkouts finden." >&2
    git -C "$_reisen_primary" worktree remove --force "$_reisen_wt" >/dev/null 2>&1 || true
    rm -rf "$_reisen_primary" "$_reisen_wt"
    exit 1
  fi
  case "$_reisen_got" in
    "$_reisen_wt"/*)
      echo "Fehler: Worktree-Lookup darf nicht auf einen Pfad unter dem Worktree zeigen." >&2
      git -C "$_reisen_primary" worktree remove --force "$_reisen_wt" >/dev/null 2>&1 || true
      rm -rf "$_reisen_primary" "$_reisen_wt"
      exit 1
      ;;
  esac
  git -C "$_reisen_primary" worktree remove --force "$_reisen_wt"
  rm -rf "$_reisen_primary"
)
(
  # shellcheck source=apple-developer.sh
  source "$ROOT/Scripts/apple-developer.sh"
  APP_STORE_CONNECT_API_KEY_KEY_ID="TESTKEYID"
  APP_STORE_CONNECT_API_KEY_ISSUER="00000000-0000-0000-0000-000000000000"
  APP_STORE_CONNECT_API_KEY_BASE64="$(printf 'reisen-asc-key-fixture' | base64)"
  unset APP_STORE_CONNECT_API_KEY_PATH
  reisen_xcodebuild_asc_auth_args
  key_path="$(reisen_asc_auth_key_path)" || {
    echo "Fehler: reisen_xcodebuild_asc_auth_args muss BASE64 in einen Key-Pfad materialisieren." >&2
    exit 1
  }
  if [[ ! -f "$key_path" ]]; then
    echo "Fehler: materialisierter App-Store-Connect-Key fehlt: ${key_path}" >&2
    exit 1
  fi
  reisen_cleanup_asc_auth_key
  if [[ -e "$key_path" ]]; then
    echo "Fehler: reisen_cleanup_asc_auth_key muss die materialisierte Key-Datei entfernen." >&2
    exit 1
  fi
  unset APP_STORE_CONNECT_API_KEY_KEY_ID APP_STORE_CONNECT_API_KEY_ISSUER APP_STORE_CONNECT_API_KEY_BASE64
  reisen_xcodebuild_asc_auth_args
  if [[ "${REISEN_ASC_AUTH_ARGS[*]}" != "-allowProvisioningUpdates" ]]; then
    echo "Fehler: ohne Key muss REISEN_ASC_AUTH_ARGS nur -allowProvisioningUpdates enthalten." >&2
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
python3 -m unittest discover -s "$ROOT/Scripts/tests" -p 'test_ci_*.py' -v

if [[ "$SKIP_BUILD" == "true" ]]; then
  swift test -v --skip-build
else
  swift test -v
fi

if [[ "$WITH_IOS_RELEASE_CHECK" == "true" ]]; then
  env CI=true REISEN_CLOUDKIT=0 bash "$ROOT/Scripts/ios-build-release-check.sh"
fi

