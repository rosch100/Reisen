#!/usr/bin/env bash
# Release-Build für Store/Private + Binary-Isolation-Check (ohne Archive/IPA).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

RELEASE_DESTINATION='generic/platform=iOS Simulator'

reisen_ios_release_check_self_test() {
  local script="$ROOT/Scripts/ios-build-release-check.sh"
  # Exact top-level destination (not self-test body alone).
  grep -Fqx "RELEASE_DESTINATION='generic/platform=iOS Simulator'" "$script"
  # Production body must not boot a simulator (ignore this self-test function).
  local production
  production="$(sed -n '/^REISEN_CI_T0="$(date +%s)"/,$p' "$script")"
  if printf '%s\n' "$production" | grep -E '^[[:space:]]*xcrun simctl boot'; then
    echo "Fehler: simctl boot darf im Release-Check-Produktionspfad nicht vorkommen." >&2
    return 1
  fi
  if printf '%s\n' "$production" | grep -E '^[[:space:]]*xcrun simctl bootstatus'; then
    echo "Fehler: simctl bootstatus darf im Release-Check-Produktionspfad nicht vorkommen." >&2
    return 1
  fi
  # Parallel Store + Private builds (background jobs + wait) + per-scheme logs —
  # assert on production path so self-test grep strings cannot satisfy themselves.
  printf '%s\n' "$production" | grep -Fq 'build_scheme_release ReiseniOS'
  printf '%s\n' "$production" | grep -Fq 'build_scheme_release ReiseniOSPrivate'
  printf '%s\n' "$production" | grep -Fq 'store_pid=$!'
  printf '%s\n' "$production" | grep -Fq 'private_pid=$!'
  printf '%s\n' "$production" | grep -Fq 'wait "$store_pid"'
  printf '%s\n' "$production" | grep -Fq 'wait "$private_pid"'
  printf '%s\n' "$production" | grep -Fq 'xcodebuild-release.log'
  printf '%s\n' "$production" | grep -Fq 'ios-verify-binary-isolation.sh'
  echo "ios-build-release-check.sh self-test: OK" >&2
}

if [[ "${1:-}" == "--self-test" ]]; then
  if [[ "$#" -ne 1 ]]; then
    echo "Fehler: --self-test nur als alleiniges Argument." >&2
    exit 2
  fi
  reisen_ios_release_check_self_test
  exit 0
fi

REISEN_CI_T0="$(date +%s)"
trap 'echo "reisen-ci-duration: script=ios-build-release-check.sh seconds=$(( $(date +%s) - REISEN_CI_T0 ))" >&2' EXIT

cd "$ROOT"

PROJECT="$ROOT/Reisen.xcodeproj"

if [[ "${REISEN_SKIP_GENERATE_IOS_PROJECT:-}" != "1" ]]; then
  bash "$ROOT/Scripts/generate-ios-project.sh"
elif [[ ! -d "$ROOT/Reisen.xcodeproj" ]]; then
  echo "Fehler: REISEN_SKIP_GENERATE_IOS_PROJECT=1 aber Reisen.xcodeproj fehlt." >&2
  exit 1
fi

build_scheme_release() {
  local scheme="$1"
  local derived="$ROOT/DerivedData/ios-release-check-${scheme}"
  local log="$derived/xcodebuild-release.log"

  if [[ "${REISEN_CI_CLEAN_DERIVED:-}" == "true" ]]; then
    rm -rf "$derived"
  fi
  mkdir -p "$derived"

  echo "Release-Build: ${scheme} (destination=${RELEASE_DESTINATION}) …" >&2
  # pipefail: xcodebuild-Fehler bleiben Exit≠0; Log für parallele Remessure/Kontention.
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$scheme" \
    -configuration Release \
    -destination "$RELEASE_DESTINATION" \
    -derivedDataPath "$derived" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    build 2>&1 | tee "$log"
}

verify_scheme_app() {
  local scheme="$1"
  local product="$2"
  local mode="$3"
  local derived="$ROOT/DerivedData/ios-release-check-${scheme}"

  local app_path
  app_path="$(find "$derived/Build/Products/Release-iphonesimulator" -maxdepth 1 -name "${product}.app" -print -quit)"
  if [[ -z "$app_path" ]]; then
    echo "Fehler: ${product}.app nicht gefunden unter $derived" >&2
    exit 1
  fi

  local main_binary="$app_path/$product"
  if [[ ! -f "$main_binary" ]]; then
    echo "Fehler: Hauptbinary fehlt in ${product}.app: $main_binary" >&2
    exit 1
  fi

  bash "$ROOT/Scripts/ios-verify-binary-isolation.sh" --mode "$mode" --app "$app_path"
}

echo "Release-Builds parallel: ReiseniOS + ReiseniOSPrivate …" >&2
build_scheme_release ReiseniOS &
store_pid=$!
build_scheme_release ReiseniOSPrivate &
private_pid=$!

store_status=0
private_status=0
wait "$store_pid" || store_status=$?
wait "$private_pid" || private_status=$?

if [[ "$store_status" -ne 0 || "$private_status" -ne 0 ]]; then
  echo "Fehler: Release-Build fehlgeschlagen (store=${store_status} private=${private_status})." >&2
  echo "Logs: DerivedData/ios-release-check-ReiseniOS/xcodebuild-release.log" >&2
  echo "      DerivedData/ios-release-check-ReiseniOSPrivate/xcodebuild-release.log" >&2
  exit 1
fi

verify_scheme_app ReiseniOS ReiseniOS store
verify_scheme_app ReiseniOSPrivate ReiseniOSPrivate private

echo "OK: Release-Builds und Binary-Isolation-Checks für Store und Private." >&2
