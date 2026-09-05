#!/usr/bin/env bash
# macOS XCUI-Smokes (SSOT). Host: XcodeGen-Scheme ReisenMac.
# bash 3.2 + set -u: niemals ein leeres Array via "${arr[@]}" expandieren.
#
# Selection (SSOT: docs/superpowers/specs/2026-09-04-macos-ui-diff-select-design.md):
#   Default lokal = Diff → -only-testing je Treffer; leer → Skip stderr + Exit 0
#   --full | CI/GITHUB_ACTIONS → ganze MacUISmokeTests
#   --reisen-ui-only-testing <args…> → Passthrough (Remote), keine Diff-Selektion
#
# REISEN_MAC_UI_CODE_SIGNING_OFF=true (Remote ohne Developer-Profile):
#   build-for-testing ohne Signatur → Ad-hoc codesign + xattr -cr →
#   test-without-building.
#   CODE_SIGNING_ALLOWED=NO allein + Start unter Gatekeeper → Dialog
#   „… ist beschädigt und kann nicht geöffnet werden“.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

REISEN_MAC_UI_CLASS_FILTER='-only-testing:ReisenMacUITests/MacUISmokeTests'

MODE=diff
ONLY_ARGS=()

reisen_macos_ui_skip_stderr() {
  # Prints SKIP_STDERR to stdout; fails closed if Python/constant unavailable.
  local msg
  if ! msg="$(
    python3 -c "import importlib.util, sys; s=importlib.util.spec_from_file_location('m', sys.argv[1]); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); print(m.SKIP_STDERR, end='')" \
      "$ROOT/Scripts/macos_ui_select_tests.py"
  )" || [[ -z "$msg" ]]; then
    echo "Fehler: SKIP_STDERR aus macos_ui_select_tests.py nicht lesbar." >&2
    return 1
  fi
  printf '%s\n' "$msg"
}

reisen_macos_ui_parse_argv() {
  MODE=diff
  ONLY_ARGS=()
  while (($#)); do
    case "$1" in
      --full)
        MODE=full
        shift
        ;;
      --reisen-ui-only-testing)
        MODE=passthrough
        shift
        while (($#)); do
          ONLY_ARGS+=("$1")
          shift
        done
        ;;
      *)
        echo "Fehler: unbekanntes Argument: $1" >&2
        return 2
        ;;
    esac
  done
  if [[ "${CI:-}" == "true" || "${GITHUB_ACTIONS:-}" == "true" ]]; then
    MODE=full
  fi
  return 0
}

reisen_macos_ui_resolve_only_args() {
  local -a resolved=()
  case "$MODE" in
    full)
      resolved=("$REISEN_MAC_UI_CLASS_FILTER")
      ;;
    passthrough)
      if ((${#ONLY_ARGS[@]} == 0)); then
        echo "Fehler: --reisen-ui-only-testing erfordert mindestens ein Argument." >&2
        return 2
      fi
      local arg
      for arg in "${ONLY_ARGS[@]}"; do
        if [[ "$arg" != -only-testing:* ]]; then
          echo "Fehler: erwartet -only-testing:…, erhalten: $arg" >&2
          return 2
        fi
      done
      resolved=("${ONLY_ARGS[@]}")
      ;;
    diff)
      local selector_out selector_status
      local repo_root="${REISEN_MAC_UI_REPO_ROOT:-$ROOT}"
      if [[ -n "${REISEN_MAC_UI_SELECT_CMD:-}" ]]; then
        selector_out="$(eval "$REISEN_MAC_UI_SELECT_CMD")"
      else
        selector_out="$(python3 "$ROOT/Scripts/macos_ui_select_tests.py" --repo-root "$repo_root")"
      fi
      selector_status=$?
      if [[ "$selector_status" -ne 0 ]]; then
        return "$selector_status"
      fi
      while IFS= read -r line; do
        [[ -n "$line" ]] && resolved+=("$line")
      done <<EOF
$selector_out
EOF
      if ((${#resolved[@]} == 0)); then
        reisen_macos_ui_skip_stderr >&2 || return 1
        # 10 = skip sentinel (not a python/selector exit code)
        return 10
      fi
      ;;
    *)
      echo "Fehler: unbekannter Modus: $MODE" >&2
      return 2
      ;;
  esac
  ONLY_ARGS=("${resolved[@]}")
  return 0
}

reisen_macos_ui_common_args() {
  local project="$1"
  local scheme="$2"
  local destination="$3"
  local derived="$4"
  local result="$5"
  printf '%s\n' \
    -project "$project" \
    -scheme "$scheme" \
    -destination "$destination" \
    -derivedDataPath "$derived" \
    -configuration Debug \
    -resultBundlePath "$result"
}

reisen_macos_ui_xcodebuild_args() {
  local project="$1"
  local scheme="$2"
  local destination="$3"
  local derived="$4"
  local result="$5"
  shift 5
  local -a args
  while IFS= read -r line; do
    args+=("$line")
  done < <(reisen_macos_ui_common_args "$project" "$scheme" "$destination" "$derived" "$result")
  if [[ "${CI:-}" == "true" || "${GITHUB_ACTIONS:-}" == "true" ]]; then
    args+=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO)
  fi
  if (($#)); then
    args+=("$@")
  fi
  args+=(test)
  printf '%s\n' "${args[@]}"
}

reisen_macos_ui_clear_gatekeeper_attrs() {
  local derived="$1"
  local products="${derived}/Build/Products"
  [[ -d "$products" ]] || return 0
  xattr -cr "$products" 2>/dev/null || true
}

reisen_macos_ui_adhoc_resign_products() {
  local derived="$1"
  local products="${derived}/Build/Products"
  local bundle ents failed=0
  [[ -d "$products" ]] || return 0
  ents="$(mktemp -t reisen-ui-empty-ents.XXXXXX)"
  cat >"$ents" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict/></plist>
PLIST
  while IFS= read -r -d '' bundle; do
    # Ohne Entitlements: Development-Cert-Pflicht entfällt; Gatekeeper braucht Signatur.
    if ! codesign --force --deep --sign - --entitlements "$ents" "$bundle" >/dev/null 2>&1 \
      && ! codesign --force --deep --sign - "$bundle" >/dev/null 2>&1; then
      echo "Fehler: Ad-hoc codesign fehlgeschlagen: $bundle" >&2
      failed=1
    fi
  done < <(find "$products" \( -name '*.app' -o -name '*.xctest' \) -print0 2>/dev/null)
  rm -f "$ents"
  [[ "$failed" -eq 0 ]] || return 1
}

reisen_macos_ui_run_unsigned_build_then_adhoc_test() {
  # Remote-Pfad: unsigned build (Entitlements ok) → Ad-hoc sign → test ohne Rebuild.
  local project="$1"
  local scheme="$2"
  local destination="$3"
  local derived="$4"
  local result="$5"
  shift 5
  local -a common
  while IFS= read -r line; do
    common+=("$line")
  done < <(reisen_macos_ui_common_args "$project" "$scheme" "$destination" "$derived" "$result")
  if (($#)); then
    common+=("$@")
  fi

  echo "macOS-UI-Tests: build-for-testing (unsigned) …" >&2
  xcodebuild "${common[@]}" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
    build-for-testing || return $?

  echo "macOS-UI-Tests: Ad-hoc codesign + xattr -cr …" >&2
  reisen_macos_ui_clear_gatekeeper_attrs "$derived"
  reisen_macos_ui_adhoc_resign_products "$derived" || return $?
  rm -rf "$result"

  echo "macOS-UI-Tests: test-without-building …" >&2
  xcodebuild "${common[@]}" test-without-building
}

if [[ "${1:-}" == "--self-test" ]]; then
  if (($# != 1)); then
    echo "Fehler: --self-test nur als alleiniges Argument (bash ./Scripts/macos-ui-test.sh --self-test)." >&2
    exit 2
  fi

  unset CI GITHUB_ACTIONS REISEN_MAC_UI_CODE_SIGNING_OFF

  local_out="$(reisen_macos_ui_xcodebuild_args /p S 'platform=macOS' /d /r.xcresult "$REISEN_MAC_UI_CLASS_FILTER")"
  printf '%s\n' "$local_out" | grep -qx -- -project
  printf '%s\n' "$local_out" | grep -qx test
  printf '%s\n' "$local_out" | grep -qx -- "$REISEN_MAC_UI_CLASS_FILTER"
  if printf '%s\n' "$local_out" | grep -q CODE_SIGNING_ALLOWED=NO; then
    echo "self-test: lokales Signing-Flag ohne CI" >&2
    exit 1
  fi
  CI=true
  ci_out="$(reisen_macos_ui_xcodebuild_args /p S 'platform=macOS' /d /r.xcresult "$REISEN_MAC_UI_CLASS_FILTER")"
  printf '%s\n' "$ci_out" | grep -qx CODE_SIGNING_ALLOWED=NO
  printf '%s\n' "$ci_out" | grep -qx CODE_SIGNING_REQUIRED=NO
  extra_out="$(reisen_macos_ui_xcodebuild_args /p S 'platform=macOS' /d /r.xcresult "$REISEN_MAC_UI_CLASS_FILTER" CODE_SIGN_IDENTITY=-)"
  printf '%s\n' "$extra_out" | grep -qx CODE_SIGN_IDENTITY=-

  skip_spec="$(reisen_macos_ui_skip_stderr)"
  printf '%s\n' "$skip_spec" | grep -Fq 'macos-ui-test: no smoke selection (diff); skip XCUI.'
  grep -Fq 'reisen_macos_ui_skip_stderr' "$ROOT/Scripts/macos-ui-test.sh"
  grep -Fq 'macos_ui_select_tests.py' "$ROOT/Scripts/macos-ui-test.sh"
  grep -Fq -e '--reisen-ui-only-testing' "$ROOT/Scripts/macos-ui-test.sh"
  grep -Fq 'keine -only-testing-Args vor xcodebuild' "$ROOT/Scripts/macos-ui-test.sh"

  unset CI GITHUB_ACTIONS
  reisen_macos_ui_parse_argv --reisen-ui-only-testing \
    -only-testing:ReisenMacUITests/MacUISmokeTests/testFoo \
    -only-testing:ReisenMacUITests/MacUISmokeTests/testBar
  [[ "$MODE" == passthrough ]]
  [[ ${#ONLY_ARGS[@]} -eq 2 ]]
  [[ "${ONLY_ARGS[0]}" == "-only-testing:ReisenMacUITests/MacUISmokeTests/testFoo" ]]
  [[ "${ONLY_ARGS[1]}" == "-only-testing:ReisenMacUITests/MacUISmokeTests/testBar" ]]

  unset CI GITHUB_ACTIONS
  reisen_macos_ui_parse_argv
  [[ "$MODE" == diff ]]
  CI=true
  reisen_macos_ui_parse_argv
  [[ "$MODE" == full ]]

  unset CI GITHUB_ACTIONS
  GITHUB_ACTIONS=true
  reisen_macos_ui_parse_argv
  [[ "$MODE" == full ]]

  unset CI GITHUB_ACTIONS
  reisen_macos_ui_parse_argv --full
  [[ "$MODE" == full ]]
  reisen_macos_ui_resolve_only_args
  [[ ${#ONLY_ARGS[@]} -eq 1 ]]
  [[ "${ONLY_ARGS[0]}" == "$REISEN_MAC_UI_CLASS_FILTER" ]]

  unset CI GITHUB_ACTIONS REISEN_MAC_UI_DIFF_BASE REISEN_MAC_UI_REPO_ROOT REISEN_MAC_UI_SELECT_CMD
  reisen_macos_ui_parse_argv
  [[ "$MODE" == diff ]]

  hermetic_repo="$(mktemp -d -t reisen-ui-select-selftest.XXXXXX)"
  hermetic_smoke="${hermetic_repo}/Tests/ReisenMacUITests"
  mkdir -p "$hermetic_smoke"
  cp "$ROOT/Tests/ReisenMacUITests/MacUISmokeTests.swift" "$hermetic_smoke/MacUISmokeTests.swift"
  (
    cd "$hermetic_repo"
    git init -b master >/dev/null 2>&1
    git config user.email "selftest@example.com"
    git config user.name "Self Test"
    git add .
    git commit -m "selftest" >/dev/null 2>&1
  )
  export REISEN_MAC_UI_REPO_ROOT="$hermetic_repo"
  export REISEN_MAC_UI_DIFF_BASE=HEAD
  set +e
  empty_resolve_stderr="$(reisen_macos_ui_resolve_only_args 2>&1 >/dev/null)"
  empty_resolve_status=$?
  set -e
  rm -rf "$hermetic_repo"
  unset REISEN_MAC_UI_REPO_ROOT REISEN_MAC_UI_DIFF_BASE
  [[ "$empty_resolve_status" -eq 10 ]]
  printf '%s\n' "$empty_resolve_stderr" | grep -Fq "$skip_spec"

  echo "macos-ui-test.sh self-test: OK" >&2
  exit 0
fi

reisen_macos_ui_parse_argv "$@" || exit $?

if ! reisen_macos_ui_resolve_only_args; then
  resolve_status=$?
  if [[ "$resolve_status" -eq 10 ]]; then
    exit 0
  fi
  exit "$resolve_status"
fi

# Guard: ohne -only-testing würde xcodebuild (bash≥5) die ganze Scheme-Suite fahren.
if ((${#ONLY_ARGS[@]} == 0)); then
  echo "Fehler: keine -only-testing-Args vor xcodebuild" >&2
  exit 2
fi

echo "macOS-UI-Tests filter (${MODE}): ${ONLY_ARGS[*]}" >&2

cd "$ROOT"

REISEN_CI_T0="$(date +%s)"
trap 'echo "reisen-ci-duration: script=macos-ui-test.sh seconds=$(( $(date +%s) - REISEN_CI_T0 ))" >&2' EXIT

export REISEN_GITHUB_ISSUE_TOKEN_EMPTY=true
unset REISEN_EMBED_GITHUB_ISSUE_TOKEN
unset REISEN_REQUIRE_GITHUB_ISSUE_TOKEN
if [[ "${REISEN_SKIP_GENERATE_IOS_PROJECT:-}" != "1" ]]; then
  bash "$ROOT/Scripts/generate-ios-project.sh"
elif [[ ! -d "$ROOT/Reisen.xcodeproj" ]]; then
  echo "Fehler: REISEN_SKIP_GENERATE_IOS_PROJECT=1 aber Reisen.xcodeproj fehlt." >&2
  exit 1
fi

PROJECT="$ROOT/Reisen.xcodeproj"
SCHEME="ReisenMac"
DERIVED="$ROOT/DerivedData/ReisenMacUITests"
RESULT="$DERIVED/macos-ui.xcresult"
LOG="$DERIVED/macos-ui-xcodebuild.log"
DESTINATION="${REISEN_MAC_DESTINATION:-platform=macOS}"

mkdir -p "$DERIVED"
rm -rf "$RESULT" "$LOG"

run_ui_tests() {
  local -a args
  while IFS= read -r line; do
    args+=("$line")
  done < <(reisen_macos_ui_xcodebuild_args "$PROJECT" "$SCHEME" "$DESTINATION" "$DERIVED" "$RESULT" "${ONLY_ARGS[@]}")
  xcodebuild "${args[@]}"
}

echo "macOS-UI-Tests: ${SCHEME} (${DESTINATION}) …" >&2
set +e
if [[ "${REISEN_MAC_UI_CODE_SIGNING_OFF:-}" == "true" ]]; then
  reisen_macos_ui_run_unsigned_build_then_adhoc_test \
    "$PROJECT" "$SCHEME" "$DESTINATION" "$DERIVED" "$RESULT" "${ONLY_ARGS[@]}" 2>&1 | tee "$LOG"
  status=${PIPESTATUS[0]}
else
  run_ui_tests 2>&1 | tee "$LOG"
  status=${PIPESTATUS[0]}
fi
set -e

reisen_macos_ui_clear_gatekeeper_attrs "$DERIVED"

if [[ "$status" -ne 0 && "${REISEN_MAC_UI_CODE_SIGNING_OFF:-}" != "true" ]]; then
  if grep -Eiq 'failed to attach|could not attach|not code signed|errSec|DTServiceHub|bootstrapping|signal kill|Early unexpected exit|beschädigt|damaged|cannot be opened' "$LOG"; then
    echo "Hinweis: Signing/Attach/Gatekeeper — Retry mit Ad-hoc-Resign-Pfad" >&2
    rm -rf "$RESULT"
    set +e
    REISEN_MAC_UI_CODE_SIGNING_OFF=true reisen_macos_ui_run_unsigned_build_then_adhoc_test \
      "$PROJECT" "$SCHEME" "$DESTINATION" "$DERIVED" "$RESULT" "${ONLY_ARGS[@]}" 2>&1 | tee -a "$LOG"
    status=${PIPESTATUS[0]}
    set -e
    reisen_macos_ui_clear_gatekeeper_attrs "$DERIVED"
  fi
fi

if [[ "$status" -ne 0 ]]; then
  echo "Fehler: macOS-UI-Tests fehlgeschlagen (Exit ${status}). xcresult: ${RESULT}" >&2
  exit "$status"
fi
