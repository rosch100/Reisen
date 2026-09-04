#!/usr/bin/env bash
# Prüft iOS-App-Binaries auf Provider-Isolation (Store vs Private).
#
# Store (ReiseniOS): linkt ReisenAppCore + ReisenSharedUI ohne ReisenProviders.
#   Keine Adapter-URLs/Symbole und keine Session-Probe-Strings (Opodo/Traveloka/billiger-mietwagen).
# Private (ReiseniOSPrivate): linkt zusätzlich ReisenProviderSync + Adapter.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# SSOT: muss zu project.yml targets.ReiseniOS / ReiseniOSPrivate passen.
STORE_BUNDLE_ID="de.roschmac.Reisen.ios"
STORE_APP_NAME="ReiseniOS"
PRIVATE_BUNDLE_ID="de.roschmac.Reisen.ios.private"
PRIVATE_APP_NAME="ReiseniOSPrivate"

usage() {
  echo "Usage: $0 --mode store|private (--app PATH | --binary PATH | --ipa PATH)" >&2
  exit 2
}

MODE=""
APP=""
BINARY=""
IPA=""
IPA_UNPACK_DIR=""

cleanup_ipa_unpack() {
  if [[ -n "${IPA_UNPACK_DIR}" && -d "${IPA_UNPACK_DIR}" ]]; then
    rm -rf "${IPA_UNPACK_DIR}"
  fi
}

trap cleanup_ipa_unpack EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    --app)
      APP="${2:-}"
      shift 2
      ;;
    --binary)
      BINARY="${2:-}"
      shift 2
      ;;
    --ipa)
      IPA="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unbekanntes Argument: $1" >&2
      usage
      ;;
  esac
done

source_count=0
[[ -n "$APP" ]] && source_count=$((source_count + 1))
[[ -n "$BINARY" ]] && source_count=$((source_count + 1))
[[ -n "$IPA" ]] && source_count=$((source_count + 1))

if [[ -z "$MODE" || "$source_count" -ne 1 ]]; then
  usage
fi

if [[ -n "$APP" && ! -d "$APP" ]]; then
  echo "Fehler: App-Bundle fehlt: $APP" >&2
  exit 1
fi

if [[ -n "$BINARY" && ! -f "$BINARY" ]]; then
  echo "Fehler: Binary fehlt: $BINARY" >&2
  exit 1
fi

if [[ -n "$IPA" && ! -f "$IPA" ]]; then
  echo "Fehler: IPA fehlt: $IPA" >&2
  exit 1
fi

# SSOT: Adapter-URLs, die Store nicht enthalten darf und Private enthalten muss.
ADAPTER_URL_MARKERS=(
  "secure.booking.com/dml/graphql"
  "d306zoyjsyarp7ifhu67rjxn52tv0t20"
  "kundenbereich.check24.de/kb/api"
  "www.getyourguide.com"
  "www.opodo.de/frontend-api/service/graphql"
  "traveloka.com/api/v2/user/whoami"
  "consumer-api.floyt.com/useraccount/v1/bookings"
)

STORE_FORBIDDEN_SYMBOLS=(
  ProviderSyncBootstrap
  Check24TravelProvider
  BookingComTravelProvider
  OpodoTravelProvider
  AirbnbTravelProvider
  GetYourGuideTravelProvider
  TravelokaTravelProvider
  BilligerMietwagenTravelProvider
  OpodoSessionProbe
  TravelokaSessionProbe
  BilligerMietwagenSessionProbe
  ProviderSessionStatusResolver
)

unpack_ipa() {
  local ipa_path="$1"
  IPA_UNPACK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/reisen-ipa-XXXXXX")"
  unzip -q -o "$ipa_path" -d "$IPA_UNPACK_DIR"

  local -a apps=()
  local candidate
  while IFS= read -r -d '' candidate; do
    apps+=("$candidate")
  done < <(find "$IPA_UNPACK_DIR/Payload" -maxdepth 1 -name '*.app' -type d -print0 2>/dev/null)

  if ((${#apps[@]} != 1)); then
    echo "Fehler: IPA muss genau ein .app in Payload enthalten (gefunden: ${#apps[@]}): $ipa_path" >&2
    exit 1
  fi
  APP="${apps[0]}"
}

read_bundle_id() {
  local app="$1"
  local plist="$app/Info.plist"
  if [[ ! -f "$plist" ]]; then
    echo "Fehler: Info.plist fehlt in $app" >&2
    exit 1
  fi
  /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist"
}

verify_store_identity() {
  local app="$1"
  local app_basename bundle_id

  app_basename="$(basename "$app" .app)"
  if [[ "$app_basename" != "$STORE_APP_NAME" ]]; then
    echo "Fehler: Store-Prüfung erwartet ${STORE_APP_NAME}.app, gefunden: $(basename "$app")" >&2
    echo "Private-Binary (z. B. ${PRIVATE_APP_NAME}) wird nicht für den App Store Check verwendet." >&2
    exit 1
  fi

  bundle_id="$(read_bundle_id "$app")"
  if [[ "$bundle_id" == "$PRIVATE_BUNDLE_ID" ]]; then
    echo "Fehler: IPA/App ist die Private-Variante ($PRIVATE_BUNDLE_ID). App Store Check scannt nur $STORE_BUNDLE_ID." >&2
    exit 1
  fi
  if [[ "$bundle_id" != "$STORE_BUNDLE_ID" ]]; then
    echo "Fehler: Store-Bundle-ID muss $STORE_BUNDLE_ID sein (ist: $bundle_id)." >&2
    exit 1
  fi
}

emit_mach_o_file() {
  local file="$1"
  if [[ -f "$file" ]] && file "$file" | grep -q "Mach-O"; then
    printf '%s\n' "$file"
  fi
}

collect_mach_o_files() {
  local target="$1"

  if [[ -f "$target" ]]; then
    emit_mach_o_file "$target"
    return
  fi

  emit_mach_o_file "$target/$(basename "$target" .app)"

  local search_root candidate
  for search_root in "$target/Frameworks" "$target/PlugIns"; do
    if [[ ! -d "$search_root" ]]; then
      continue
    fi
    while IFS= read -r -d '' candidate; do
      emit_mach_o_file "$candidate"
    done < <(find "$search_root" -type f -print0 2>/dev/null)
  done
}

contains_string() {
  local file="$1"
  local marker="$2"
  # grep -a auf der Binary vermeidet strings|grep-Pipefail/SIGPIPE auf großen CI-Binaries.
  grep -aFq "$marker" "$file" 2>/dev/null
}

contains_symbol() {
  local file="$1"
  local marker="$2"
  nm "$file" 2>/dev/null | grep -Fq "$marker"
}

verify_store_files() {
  local file="$1"
  local marker

  for marker in "${ADAPTER_URL_MARKERS[@]}"; do
    if contains_string "$file" "$marker"; then
      echo "Fehler: Store-Binary enthält Adapter-exklusiven String: $marker ($file)" >&2
      exit 1
    fi
  done

  for marker in "${STORE_FORBIDDEN_SYMBOLS[@]}"; do
    if contains_symbol "$file" "$marker"; then
      echo "Fehler: Store-Binary enthält verbotenes Adapter-Symbol: $marker ($file)" >&2
      exit 1
    fi
  done
}

verify_private_markers() {
  local -a files=("$@")
  local marker found file

  for marker in "${ADAPTER_URL_MARKERS[@]}"; do
    found=0
    for file in "${files[@]}"; do
      if contains_string "$file" "$marker"; then
        found=1
        break
      fi
    done
    if [[ "$found" -ne 1 ]]; then
      echo "Fehler: Private-Bundle fehlt Marker: $marker" >&2
      exit 1
    fi
  done
}

run_verify() {
  local target="${APP:-$BINARY}"
  local -a files=()
  local file

  while IFS= read -r file; do
    if [[ -n "$file" ]]; then
      files+=("$file")
    fi
  done < <(collect_mach_o_files "$target")

  if ((${#files[@]} == 0)); then
    echo "Fehler: Keine Mach-O-Dateien in $target gefunden." >&2
    exit 1
  fi

  case "$MODE" in
    store)
      for file in "${files[@]}"; do
        verify_store_files "$file"
      done
      echo "OK: Store-Bundle ${STORE_BUNDLE_ID} (${#files[@]} Mach-O) ohne Provider-Adapter- und Session-Probe-Strings." >&2
      ;;
    private)
      verify_private_markers "${files[@]}"
      echo "OK: Private-Bundle (${#files[@]} Mach-O) enthält alle Provider-Sync-Marker." >&2
      ;;
  esac
}

if [[ -n "$IPA" ]]; then
  unpack_ipa "$IPA"
fi

if [[ -n "$APP" && "$MODE" == "store" ]]; then
  verify_store_identity "$APP"
fi

case "$MODE" in
  store|private) run_verify ;;
  *)
    echo "Fehler: Unbekannter Modus: $MODE (store|private)" >&2
    exit 2
    ;;
esac
