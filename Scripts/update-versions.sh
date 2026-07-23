#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

VERIFY=false
UPDATE_SWIFT_TOOLS_VERSION=true
SWIFT_TARGET_VERSION="6.4"

usage() {
  cat <<'EOF'
Usage: Scripts/update-versions.sh [--verify] [--no-update-swift-tools-version]

Updates version pins in:
  - .github/workflows/*.yml (GitHub Actions pinned SHAs)
  - actionlint download URL (vX.Y.Z)
  - setup-xcode xcode-version (latest stable for macos-XX)
  - Package.swift swift-tools-version (optional)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verify) VERIFY=true; shift ;;
    --no-update-swift-tools-version) UPDATE_SWIFT_TOOLS_VERSION=false; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing command: $1" >&2; exit 1; }
}

require_cmd gh
require_cmd jq
require_cmd curl
require_cmd rg
require_cmd perl

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

get_latest_release_tag() {
  # $1 = owner/repo
  gh api "repos/$1/releases/latest" --jq .tag_name
}

get_release_tag_commit_sha() {
  # $1 = owner/repo, $2 = tag_name
  # Works for tags like "v1.7.12" and similar.
  gh api "repos/$1/commits/$2" --jq .sha
}

replace_uses_sha() {
  # $1 = file, $2 = full action name without @ref (e.g. actions/checkout)
  # $3 = sha to write
  local file="$1"
  local action="$2"
  local sha="$3"

  local tmp="$tmpdir/$(basename "$file").tmp"
  # Replace only the ref part after @, keep comments.
  sed -E "s|(uses: ${action}@)[^[:space:]]+|\\1${sha}|g" "$file" > "$tmp"
  mv "$tmp" "$file"
}

replace_codeql_uses_sha() {
  # $1 = file, $2 = action variant (init|analyze|upload-sarif), $3 = sha
  local file="$1"
  local variant="$2"
  local sha="$3"
  local tmp="$tmpdir/$(basename "$file").tmp"
  sed -E "s|(uses: github/codeql-action/${variant}@)[^[:space:]]+|\\1${sha}|g" "$file" > "$tmp"
  mv "$tmp" "$file"
}

replace_actionlint_download() {
  # Updates: https://raw.githubusercontent.com/rhysd/actionlint/<ref>/scripts/download-actionlint.bash
  local file=".github/workflows/actionlint.yml"
  local tag sha
  tag="$(get_latest_release_tag "rhysd/actionlint")"
  sha="$(get_release_tag_commit_sha "rhysd/actionlint" "$tag")"

  local tmp="$tmpdir/actionlint.yml.tmp"
  sed -E "s#https://raw\\.githubusercontent\\.com/rhysd/actionlint/[^/]+/scripts/download-actionlint\\.bash#https://raw.githubusercontent.com/rhysd/actionlint/${sha}/scripts/download-actionlint.bash#g" \
    "$file" > "$tmp"
  mv "$tmp" "$file"
}

replace_swift_tools_version() {
  local file="Package.swift"
  if [[ "$UPDATE_SWIFT_TOOLS_VERSION" != "true" ]]; then
    return 0
  fi

  local swift_version="$SWIFT_TARGET_VERSION"
  # swift_version example: "6.4"
  if [[ -z "$swift_version" ]]; then
    echo "SWIFT_TARGET_VERSION is not configured" >&2
    exit 1
  fi

  # Validate that the configured target matches a version-number pattern like X.Y
  if ! [[ "$swift_version" =~ ^[0-9]+\.[0-9]+$ ]]; then
    echo "SWIFT_TARGET_VERSION must match pattern X.Y (e.g., 6.4), got: $swift_version" >&2
    exit 1
  fi

  # Use perl here instead of sed because the sed expression can break on macOS
  # when constructed via shell variables.
  perl -pi -e 's{^// swift-tools-version: [0-9]+\.[0-9]+$}{// swift-tools-version: '"$swift_version"'}' "$file"
}

update_xcode_versions_in_workflows() {
  # Best practice: let setup-xcode select the newest stable Xcode for the runner image.
  # This avoids fragile scraping of upstream markdown tables.
  for wf in .github/workflows/*.yml; do
    if rg -q "xcode-version:" "$wf"; then
      sed -E -i.bak \
        "s/(xcode-version:[[:space:]]*)\"[0-9]+\\.[0-9.]+\"/\\1latest-stable/g; s/(xcode-version:[[:space:]]*)'[0-9]+\\.[0-9.]+'/\\1latest-stable/g; s/(xcode-version:[[:space:]]*)[0-9]+\\.[0-9.]+/\\1latest-stable/g" \
        "$wf"
      rm -f "${wf}.bak"
    fi
  done
}

update_action_pins_in_workflows() {
  # Allowlist: only update known actions that we pinned.
  # Each entry: owner/repo => action name used in workflow (owner/repo or owner/repo/<subaction>).

  local files=(.github/workflows/*.yml)

  # Simple actions (no subaction path in the `uses:` line).
  declare -A simple_actions=(
    ["actions/checkout"]=""
    ["actions/cache"]=""
    ["maxim-lobanov/setup-xcode"]=""
    ["fwal/setup-swift"]=""
    ["ossf/scorecard-action"]=""
    ["actions/dependency-review-action"]=""
    ["gitleaks/gitleaks-action"]=""
    ["softprops/action-gh-release"]=""
  )

  for action in "${!simple_actions[@]}"; do
    local tag sha
    tag="$(get_latest_release_tag "$action")"
    sha="$(get_release_tag_commit_sha "$action" "$tag")"
    for wf in "${files[@]}"; do
      if rg -q "uses: ${action}@" "$wf"; then
        replace_uses_sha "$wf" "$action" "$sha"
      fi
    done
  done

  # CodeQL subactions.
  local codeql_owner_repo="github/codeql-action"
  local variants=(init analyze upload-sarif)
  local tag
  tag="$(get_latest_release_tag "$codeql_owner_repo")"
  local sha
  sha="$(get_release_tag_commit_sha "$codeql_owner_repo" "$tag")"

  for wf in "${files[@]}"; do
    for variant in "${variants[@]}"; do
      if rg -q "uses: ${codeql_owner_repo}/${variant}@" "$wf"; then
        replace_codeql_uses_sha "$wf" "$variant" "$sha"
      fi
    done
  done
}

main() {
  update_action_pins_in_workflows
  replace_actionlint_download
  update_xcode_versions_in_workflows
  replace_swift_tools_version

  if [[ "$VERIFY" == "true" ]]; then
    echo "Running verification..."
    swift build --build-tests -v
    bash ./Scripts/ci-test.sh
  fi
}

main

