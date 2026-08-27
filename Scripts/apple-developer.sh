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

# xcodebuild-Flags für App Store Connect API Key (nicht-interaktiv).
# Materialisiert .p8 aus APP_STORE_CONNECT_API_KEY_BASE64, wenn kein PATH gesetzt ist.
# Gibt nichts aus, wenn KEY_ID/ISSUER fehlen (Aufrufer entscheidet: lokal Apple-ID).
reisen_xcodebuild_asc_auth_args() {
  if [[ -z "${APP_STORE_CONNECT_API_KEY_KEY_ID:-}" ||
        -z "${APP_STORE_CONNECT_API_KEY_ISSUER:-}" ]]; then
    return 0
  fi

  local key_path="${APP_STORE_CONNECT_API_KEY_PATH:-}"
  if [[ -z "$key_path" && -n "${APP_STORE_CONNECT_API_KEY_BASE64:-}" ]]; then
    local key_dir
    key_dir="$(mktemp -d "${TMPDIR:-/tmp}/reisen-asc-key.XXXXXX")"
    key_path="$key_dir/AuthKey_${APP_STORE_CONNECT_API_KEY_KEY_ID}.p8"
    if ! printf '%s' "$APP_STORE_CONNECT_API_KEY_BASE64" | base64 --decode >"$key_path"; then
      echo "Fehler: APP_STORE_CONNECT_API_KEY_BASE64 ist kein gültiges Base64." >&2
      return 1
    fi
    chmod 600 "$key_path"
  fi
  if [[ -z "$key_path" ]]; then
    local candidate
    for candidate in \
      "$HOME/keys/AuthKey_${APP_STORE_CONNECT_API_KEY_KEY_ID}.p8" \
      "$HOME/private_keys/AuthKey_${APP_STORE_CONNECT_API_KEY_KEY_ID}.p8"
    do
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
    return 1
  fi

  printf '%s\n' \
    -allowProvisioningUpdates \
    -authenticationKeyPath "$key_path" \
    -authenticationKeyID "$APP_STORE_CONNECT_API_KEY_KEY_ID" \
    -authenticationKeyIssuerID "$APP_STORE_CONNECT_API_KEY_ISSUER"
}
