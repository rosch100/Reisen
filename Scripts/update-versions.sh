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

get_latest_stable_xcode_for_macos() {
  # $1 = major version, e.g. 26 for macos-26
  local macos_major="$1"
  local doc_url="https://raw.githubusercontent.com/actions/runner-images/master/images/macos/macos-${macos_major}-Readme.md"
  local doc_file="$tmpdir/macos-${macos_major}-Readme.md"

  curl -fsSL "$doc_url" -o "$doc_file"

  # Extract Xcode versions like 26.6 from the Xcode table.
  # Table rows look like: | 26.6           | 17F113 | ...
  # We parse the second pipe-separated column and keep only entries matching "^<major>.<minor+>$".
  local latest
  latest="$(
    awk -F'|' -v major="$macos_major" '
      {
        v=$2;
        gsub(/^[ \t]+|[ \t]+$/, "", v);
        if (v ~ ("^" major "\\.[0-9]+$")) print v;
      }
    ' "$doc_file" \
      | sort -V \
      | tail -n 1
  )"

  if [[ -z "$latest" ]]; then
    echo "Unable to determine latest stable Xcode for macos-${macos_major}" >&2
    exit 1
  fi

  echo "$latest"
}

update_xcode_versions_in_workflows() {
  # Currently focuses on macos-26 in this repo; but handles any macos-<N> found.
  local major
  for major in $(rg -o --no-filename "macos-[0-9]+" .github/workflows/*.yml | awk -F'-' '{print $2}' | sort -u); do
    local stable_xcode
    stable_xcode="$(get_latest_stable_xcode_for_macos "$major")"

    for wf in .github/workflows/*.yml; do
      # Only touch xcode-version lines for workflows that reference this macos runner.
      if rg -n "runs-on: macos-${major}" "$wf" >/dev/null 2>&1; then
        local tmp="$tmpdir/$(basename "$wf").tmp"
        # Replace lines like: xcode-version: "26.0" or xcode-version: '26.0.1'
        sed -E "s|(xcode-version: ['\"])${major}\\.[0-9.]+(['\"]$)|\\1${stable_xcode}\\2|g" \
          "$wf" > "$tmp"
        mv "$tmp" "$wf"
      fi
    done
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

