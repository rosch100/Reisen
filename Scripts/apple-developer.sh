#!/usr/bin/env bash
# SSOT-Helfer für Apple-Developer-Team und Signing-Identities.
# Wird von anderen Scripts sourced (nicht direkt ausgeführt).

reisen_apple_developer_root() {
  local here
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  printf '%s\n' "$here"
}

# Team-ID aus APPLE_TEAM_ID oder project.yml (optional, für lokales Signing).
reisen_apple_team_id() {
  if [[ -n "${APPLE_TEAM_ID:-}" && "${APPLE_TEAM_ID}" =~ ^[A-Z0-9]{10}$ ]]; then
    printf '%s\n' "$APPLE_TEAM_ID"
    return 0
  fi

  local spec
  spec="$(reisen_apple_developer_root)/project.yml"
  if [[ ! -f "$spec" ]]; then
    echo "Fehler: project.yml fehlt: $spec" >&2
    return 1
  fi
  local team_id
  team_id="$(
    awk '
      /^[[:space:]]*DEVELOPMENT_TEAM:[[:space:]]*/ {
        val=$2
        gsub(/"/, "", val)
        if (val ~ /^[A-Z0-9]{10}$/) {
          print val
          exit
        }
      }
    ' "$spec"
  )"
  if [[ -z "$team_id" ]]; then
    echo "Fehler: Apple Team ID fehlt. Setze APPLE_TEAM_ID oder DEVELOPMENT_TEAM in project.yml." >&2
    return 1
  fi
  printf '%s\n' "$team_id"
}

# Bundle-ID für ein XcodeGen-Target aus project.yml (SSOT).
reisen_bundle_id_for_target() {
  local target_name="$1"
  local spec
  spec="$(reisen_apple_developer_root)/project.yml"
  if [[ ! -f "$spec" ]]; then
    echo "Fehler: project.yml fehlt: $spec" >&2
    return 1
  fi
  local bundle_id
  bundle_id="$(
    awk -v target="$target_name" '
      $1 == target":" { in_target=1; next }
      in_target && /^  [A-Za-z0-9]/ { in_target=0 }
      in_target && /PRODUCT_BUNDLE_IDENTIFIER:/ {
        sub(/^[[:space:]]*PRODUCT_BUNDLE_IDENTIFIER:[[:space:]]*/, "")
        print
        exit
      }
    ' "$spec"
  )"
  if [[ -z "$bundle_id" ]]; then
    echo "Fehler: PRODUCT_BUNDLE_IDENTIFIER für Target ${target_name} fehlt in project.yml." >&2
    return 1
  fi
  printf '%s\n' "$bundle_id"
}

reisen_macos_bundle_id() {
  reisen_bundle_id_for_target ReisenMac
}

reisen_ios_bundle_id() {
  reisen_bundle_id_for_target ReiseniOS
}

reisen_icloud_container_id() {
  printf 'iCloud.%s\n' "$(reisen_macos_bundle_id)"
}

# Apple-Development-Identity, deren Zertifikat-OU zur Team-ID passt.
reisen_apple_development_identity() {
  local team_id="${1:-}"
  if [[ -z "$team_id" ]]; then
    team_id="$(reisen_apple_team_id)" || return 1
  fi

  local name subject
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    subject="$(security find-certificate -c "$name" -p 2>/dev/null | openssl x509 -noout -subject 2>/dev/null || true)"
    if [[ "$subject" == *", OU=${team_id},"* || "$subject" == *"OU=${team_id},"* ]]; then
      printf '%s\n' "$name"
      return 0
    fi
  done < <(
    security find-identity -v -p codesigning 2>/dev/null |
      awk -F'"' '/Apple Development:/ {print $2}'
  )

  echo "Fehler: Keine Apple-Development-Identity für Team ${team_id} in der Keychain." >&2
  echo "Xcode → Settings → Accounts → Apple-ID anmelden, dann Signing Certificate erzeugen." >&2
  return 1
}

# codesign-Identity: lokal Apple Development, in CI explizit ad-hoc.
reisen_macos_codesign_identity() {
  if [[ "${CI:-}" == "true" || "${GITHUB_ACTIONS:-}" == "true" ]]; then
    printf '%s\n' "-"
    return 0
  fi
  reisen_apple_development_identity
}

# Temp-Verzeichnis nur für aus BASE64 materialisierte .p8 (nicht für APP_STORE_CONNECT_API_KEY_PATH).
_reisen_asc_auth_key_temp_dir=""
_reisen_asc_auth_key_cleanup_registered=""
_reisen_resolved_asc_key_path=""
REISEN_ASC_AUTH_ARGS=()

reisen_cleanup_asc_auth_key() {
  if [[ -n "${_reisen_asc_auth_key_temp_dir:-}" && -d "$_reisen_asc_auth_key_temp_dir" ]]; then
    rm -rf "$_reisen_asc_auth_key_temp_dir"
  fi
  _reisen_asc_auth_key_temp_dir=""
  _reisen_resolved_asc_key_path=""
}

reisen_register_asc_auth_key_cleanup() {
  if [[ "${_reisen_asc_auth_key_cleanup_registered}" == "1" ]]; then
    return 0
  fi
  _reisen_asc_auth_key_cleanup_registered=1
  trap reisen_cleanup_asc_auth_key EXIT
}

# Setzt _reisen_resolved_asc_key_path (leer = kein Key). Nicht per stdout — $() wäre eine Subshell.
reisen_resolve_asc_auth_key_path() {
  _reisen_resolved_asc_key_path=""
  local key_path="${APP_STORE_CONNECT_API_KEY_PATH:-}"
  local key_name="AuthKey_${APP_STORE_CONNECT_API_KEY_KEY_ID}.p8"
  if [[ -z "$key_path" && -n "${APP_STORE_CONNECT_API_KEY_BASE64:-}" ]]; then
    local key_dir
    reisen_cleanup_asc_auth_key
    key_dir="$(mktemp -d "${TMPDIR:-/tmp}/reisen-asc-key.XXXXXX")"
    _reisen_asc_auth_key_temp_dir="$key_dir"
    key_path="$key_dir/$key_name"
    if ! printf '%s' "$APP_STORE_CONNECT_API_KEY_BASE64" | base64 --decode >"$key_path"; then
      echo "Fehler: APP_STORE_CONNECT_API_KEY_BASE64 ist kein gültiges Base64." >&2
      reisen_cleanup_asc_auth_key
      return 1
    fi
    chmod 600 "$key_path"
    reisen_register_asc_auth_key_cleanup
  fi
  if [[ -z "$key_path" ]]; then
    local candidate
    for candidate in "$HOME/keys/$key_name" "$HOME/private_keys/$key_name"; do
      if [[ -f "$candidate" ]]; then
        key_path="$candidate"
        break
      fi
    done
  fi
  if [[ -z "$key_path" || ! -f "$key_path" ]]; then
    return 0
  fi
  if [[ ! -s "$key_path" ]]; then
    echo "Fehler: App Store Connect API Key-Datei ist leer: $key_path" >&2
    reisen_cleanup_asc_auth_key
    return 1
  fi
  _reisen_resolved_asc_key_path="$key_path"
}

reisen_asc_auth_key_path() {
  if [[ -z "${_reisen_resolved_asc_key_path:-}" ]]; then
    return 1
  fi
  printf '%s\n' "$_reisen_resolved_asc_key_path"
}

# Schreibt REISEN_ASC_AUTH_ARGS im aktuellen Shell (nicht per stdout).
# Immer mindestens -allowProvisioningUpdates; mit Key zusätzlich ASC-Auth-Flags.
# Materialisiert .p8 aus APP_STORE_CONNECT_API_KEY_BASE64, wenn kein PATH gesetzt ist.
reisen_xcodebuild_asc_auth_args() {
  REISEN_ASC_AUTH_ARGS=(-allowProvisioningUpdates)
  _reisen_resolved_asc_key_path=""
  if [[ -z "${APP_STORE_CONNECT_API_KEY_KEY_ID:-}" ||
        -z "${APP_STORE_CONNECT_API_KEY_ISSUER:-}" ]]; then
    return 0
  fi
  reisen_resolve_asc_auth_key_path || return 1
  local key_path="${_reisen_resolved_asc_key_path}"
  if [[ -z "$key_path" ]]; then
    return 0
  fi
  REISEN_ASC_AUTH_ARGS+=(
    -authenticationKeyPath "$key_path"
    -authenticationKeyID "$APP_STORE_CONNECT_API_KEY_KEY_ID"
    -authenticationKeyIssuerID "$APP_STORE_CONNECT_API_KEY_ISSUER"
  )
}

reisen_xcodebuild_asc_device_auth_args() {
  reisen_xcodebuild_asc_auth_args || return 1
  REISEN_ASC_AUTH_ARGS+=(-allowProvisioningDeviceRegistration)
}
