#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

VERIFY=false
UPDATE_SWIFT_TOOLS_VERSION=true
# Always derive swift-tools-version from the Swift actually installed on the runner
# to avoid selecting a version that isn't available on the current environment.

usage() {
  cat <<'EOF'
Usage: Scripts/update-versions.sh [--verify] [--no-update-swift-tools-version]

Updates toolchain/version pins not covered by Dependabot:
  - actionlint download URL (commit SHA in installer script)
  - setup-xcode xcode-version (latest-stable)
  - Package.swift swift-tools-version (optional)
  - GITLEAKS_VERSION in gitleaks.yml

GitHub Action SHA pins are updated by Dependabot (see .github/dependabot.yml).
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
require_cmd perl

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

# $1 = file path, $2 = sed -E expression
replace_in_file() {
  local file="$1"
  local expr="$2"
  local tmp="$tmpdir/$(basename "$file").$$.tmp"
  sed -E "$expr" "$file" > "$tmp"
  mv "$tmp" "$file"
}

latest_release_tag() {
  gh api "repos/$1/releases/latest" --jq .tag_name
}

release_tag_commit_sha() {
  gh api "repos/$1/commits/$2" --jq .sha
}

replace_actionlint_download() {
  local file=".github/workflows/actionlint.yml"
  local tag sha
  tag="$(latest_release_tag "rhysd/actionlint")"
  sha="$(release_tag_commit_sha "rhysd/actionlint" "$tag")"
  replace_in_file "$file" \
    "s#https://raw\\.githubusercontent\\.com/rhysd/actionlint/[^/]+/scripts/download-actionlint\\.bash#https://raw.githubusercontent.com/rhysd/actionlint/${sha}/scripts/download-actionlint.bash#g"
}

replace_gitleaks_version() {
  local file=".github/workflows/gitleaks.yml"
  local tag version
  tag="$(latest_release_tag "gitleaks/gitleaks")"
  version="${tag#v}"

  if [[ -z "$version" ]]; then
    echo "Unable to detect latest gitleaks version from tag: $tag" >&2
    exit 1
  fi

  replace_in_file "$file" \
    "s/(GITLEAKS_VERSION:[[:space:]]*)[0-9]+\\.[0-9]+\\.[0-9]+/\\1${version}/"
}

replace_swift_tools_version() {
  local file="Package.swift"
  if [[ "$UPDATE_SWIFT_TOOLS_VERSION" != "true" ]]; then
    return 0
  fi

  local swift_raw swift_tools_version
  swift_raw="$(swift --version | awk '/Apple Swift version/ {print $4; exit}')"
  swift_tools_version="$(printf '%s' "$swift_raw" | awk -F. '{print $1 "." $2}')"

  if [[ -z "$swift_raw" || -z "$swift_tools_version" ]]; then
    echo "Unable to detect installed Swift version to set swift-tools-version" >&2
    exit 1
  fi

  if ! [[ "$swift_tools_version" =~ ^[0-9]+\.[0-9]+$ ]]; then
    echo "Derived swift-tools-version must match pattern X.Y, got: $swift_tools_version (raw: $swift_raw)" >&2
    exit 1
  fi

  # perl: macOS sed struggles with this shell-variable substitution.
  perl -pi -e 's{^// swift-tools-version: [0-9]+\.[0-9]+(\.[0-9]+)?$}{// swift-tools-version: '"$swift_tools_version"'}' "$file"
}

update_xcode_versions_in_workflows() {
  # Prefer setup-xcode latest-stable over fragile scraped Xcode numbers.
  local wf
  for wf in .github/workflows/*.yml; do
    replace_in_file "$wf" \
      "s/(xcode-version:[[:space:]]*)\"[0-9]+\\.[0-9.]+\"/\\1latest-stable/g; s/(xcode-version:[[:space:]]*)'[0-9]+\\.[0-9.]+'/\\1latest-stable/g; s/(xcode-version:[[:space:]]*)[0-9]+\\.[0-9.]+/\\1latest-stable/g"
  done
}

has_uncommitted_changes() {
  ! git diff --quiet || ! git diff --cached --quiet
}

run_verification_if_needed() {
  if [[ "$VERIFY" != "true" ]]; then
    return 0
  fi
  if ! has_uncommitted_changes; then
    echo "Skipping verification: no file changes after version update."
    return 0
  fi
  echo "Running verification (files changed)..."
  swift build --build-tests -v
  bash ./Scripts/ci-test.sh
}

main() {
  replace_actionlint_download
  replace_gitleaks_version
  update_xcode_versions_in_workflows
  replace_swift_tools_version
  run_verification_if_needed
}

main
