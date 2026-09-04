#!/usr/bin/env bash
# Zwei-Geräte-iCloud-Sync-Verifikation (SSOT).
# Gerät A seedet Trip/Bookings/Gap (+ lokales Reminder), Gerät B erwartet Cloud-Daten ohne Reminder.
#
# Voraussetzung: Beide Simulatoren mit demselben iCloud-Account angemeldet.
# CloudKit muss aktiv sein (kein REISEN_CLOUDKIT=0 / CI=true beim Launch).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# shellcheck source=apple-developer.sh
source "$ROOT/Scripts/apple-developer.sh"

BUNDLE_ID="$(reisen_ios_bundle_id)"
SCHEME="ReiseniOS"
PROJECT="$ROOT/Reisen.xcodeproj"
DERIVED="$ROOT/DerivedData/ReiseniOS"
RESULT_REL="Library/Application Support/Voyenna/verify-two-device-result.json"

DEVICE_A_NAME="${IOS_SIMULATOR_A:-iPad Pro 13-inch (M5)}"
DEVICE_B_NAME="${IOS_SIMULATOR_B:-iPhone 17 Pro}"
SEED_TIMEOUT_SEC="${REISEN_VERIFY_SEED_TIMEOUT:-90}"
EXPECT_TIMEOUT_SEC="${REISEN_VERIFY_EXPECT_TIMEOUT:-120}"

resolve_udid() {
  local name="$1"
  local line=""
  # Prefer already-booted instances of the named device.
  line="$(xcrun simctl list devices available \
    | grep -F "$name (" \
    | grep -F '(Booted)' \
    | head -1 || true)"
  if [[ -z "$line" ]]; then
    line="$(xcrun simctl list devices available \
      | grep -F "$name (" \
      | head -1 || true)"
  fi
  printf '%s\n' "$line" | sed -E 's/.*\(([0-9A-Fa-f-]{36})\).*/\1/' || true
}

wait_for_result() {
  local udid="$1"
  local timeout_sec="$2"
  local label="$3"
  local deadline=$((SECONDS + timeout_sec))
  local data_container=""
  local result_path=""

  while (( SECONDS < deadline )); do
    data_container="$(xcrun simctl get_app_container "$udid" "$BUNDLE_ID" data 2>/dev/null || true)"
    if [[ -n "$data_container" ]]; then
      result_path="$data_container/$RESULT_REL"
      if [[ -f "$result_path" ]]; then
        echo "---- $label result ----" >&2
        cat "$result_path" >&2
        echo >&2
        # ok == true?
        if grep -q '"ok"[[:space:]]*:[[:space:]]*true' "$result_path"; then
          printf '%s\n' "$result_path"
          return 0
        fi
        echo "Fehler: $label meldet ok=false." >&2
        if grep -q 'noAccount' "$result_path"; then
          echo "Hinweis: Auf beiden Simulatoren denselben iCloud-Account anmelden (Settings → Apple Account), dann erneut:" >&2
          echo "  bash ./Scripts/verify-two-device-icloud.sh" >&2
        fi
        return 1
      fi
    fi
    sleep 2
  done

  echo "Fehler: Timeout ($timeout_sec s) ohne Result-Datei für $label." >&2
  if [[ -n "${data_container:-}" ]]; then
    echo "App-Data: $data_container" >&2
  fi
  return 1
}

UDID_A="$(resolve_udid "$DEVICE_A_NAME")"
UDID_B="$(resolve_udid "$DEVICE_B_NAME")"

if [[ -z "$UDID_A" ]]; then
  echo "Fehler: Simulator A nicht gefunden: $DEVICE_A_NAME" >&2
  exit 1
fi
if [[ -z "$UDID_B" ]]; then
  echo "Fehler: Simulator B nicht gefunden: $DEVICE_B_NAME" >&2
  exit 1
fi
if [[ "$UDID_A" == "$UDID_B" ]]; then
  echo "Fehler: Gerät A und B müssen unterschiedlich sein." >&2
  exit 1
fi

echo "Device A: $DEVICE_A_NAME ($UDID_A)" >&2
echo "Device B: $DEVICE_B_NAME ($UDID_B)" >&2

bash "$ROOT/Scripts/generate-ios-project.sh"

xcrun simctl boot "$UDID_A" 2>/dev/null || true
xcrun simctl boot "$UDID_B" 2>/dev/null || true
xcrun simctl bootstatus "$UDID_A" -b
xcrun simctl bootstatus "$UDID_B" -b

echo "Build ReiseniOS (CloudKit enabled)…" >&2
# Explizit CloudKit erlauben — CI/REISEN_CLOUDKIT=0 nicht übernehmen.
env -u CI -u REISEN_CLOUDKIT xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$UDID_A" \
  -derivedDataPath "$DERIVED" \
  -configuration Debug \
  build

APP_PATH="$(find "$DERIVED" -path '*/Debug-iphonesimulator/ReiseniOS.app' -type d | head -1)"
if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "Fehler: ReiseniOS.app nicht unter DerivedData gefunden." >&2
  exit 1
fi

xcrun simctl uninstall "$UDID_A" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl uninstall "$UDID_B" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$UDID_A" "$APP_PATH"
xcrun simctl install "$UDID_B" "$APP_PATH"

echo "Seed auf Gerät A…" >&2
xcrun simctl terminate "$UDID_A" "$BUNDLE_ID" 2>/dev/null || true
# Env (SIMCTL_CHILD_*) + argv — beide Wege, falls einer vom Runtime-Pfad gefressen wird.
SIMCTL_CHILD_REISEN_VERIFY_SEED=1 \
  xcrun simctl launch "$UDID_A" "$BUNDLE_ID" -- -REISEN_VERIFY_SEED

SEED_RESULT="$(wait_for_result "$UDID_A" "$SEED_TIMEOUT_SEC" "seed")"

echo "Expect auf Gerät B…" >&2
xcrun simctl terminate "$UDID_B" "$BUNDLE_ID" 2>/dev/null || true
SIMCTL_CHILD_REISEN_VERIFY_EXPECT=1 \
  xcrun simctl launch "$UDID_B" "$BUNDLE_ID" -- -REISEN_VERIFY_EXPECT

EXPECT_RESULT="$(wait_for_result "$UDID_B" "$EXPECT_TIMEOUT_SEC" "expect")"

echo "Zwei-Geräte-iCloud-Sync OK." >&2
echo "seed=$SEED_RESULT"
echo "expect=$EXPECT_RESULT"
