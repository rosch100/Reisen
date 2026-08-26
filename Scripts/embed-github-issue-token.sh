#!/usr/bin/env bash
# Schreibt GitHubIssueToken.generated.swift: Stub (leer) oder XOR-Payload.
# Token/Base64 werden niemals geloggt.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/Sources/ReisenAppCore/GitHubIssues/GitHubIssueToken.generated.swift"
STUB="$ROOT/Sources/ReisenAppCore/GitHubIssues/GitHubIssueToken.generated.swift.stub"
REQUIRE="${REISEN_REQUIRE_GITHUB_ISSUE_TOKEN:-false}"
EMPTY="${REISEN_GITHUB_ISSUE_TOKEN_EMPTY:-false}"

# xtrace würde Secrets in die Konsole schreiben.
set +x

export REISEN_EMBED_REQUIRE="$REQUIRE"
export REISEN_EMBED_EMPTY="$EMPTY"
export REISEN_EMBED_OUT="$OUT"
export REISEN_EMBED_STUB="$STUB"
export REISEN_EMBED_ROOT="$ROOT"

python3 <<'PY'
import base64
import os
import secrets
import sys

out = os.environ["REISEN_EMBED_OUT"]
stub = os.environ["REISEN_EMBED_STUB"]
root = os.environ["REISEN_EMBED_ROOT"]
require = os.environ.get("REISEN_EMBED_REQUIRE", "false") == "true"
empty = os.environ.get("REISEN_EMBED_EMPTY", "false") == "true"
plain = os.environ.get("REISEN_GITHUB_ISSUES_TOKEN", "").strip()
b64 = os.environ.get("REISEN_GITHUB_ISSUES_TOKEN_BASE64", "").strip()
token_file = os.path.join(root, "Secrets", "github-issues.token")


def write_from_stub():
    if not os.path.isfile(stub):
        print("Fehler: GitHubIssueToken.generated.swift.stub fehlt.", file=sys.stderr)
        sys.exit(1)
    with open(stub, encoding="utf-8") as handle:
        content = handle.read()
    if "static let bytes: [UInt8] = []" not in content or "static let key: [UInt8] = []" not in content:
        print("Fehler: Stub muss leere bytes/key-Arrays enthalten.", file=sys.stderr)
        sys.exit(1)
    if "0x" in content:
        print("Fehler: Stub darf keine XOR-Bytes enthalten.", file=sys.stderr)
        sys.exit(1)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        handle.write(content)


if empty and not require:
    write_from_stub()
    print("OK: GitHub-Issue-Token-Payload aus Stub (leer).", file=sys.stderr)
    sys.exit(0)

if not plain and os.path.isfile(token_file):
    with open(token_file, encoding="utf-8") as handle:
        plain = handle.read().strip()

if not plain:
    import subprocess
    keychain = subprocess.run(
        [
            "security",
            "find-generic-password",
            "-a",
            "reisen",
            "-s",
            "reisen.github-issues-token",
            "-w",
        ],
        capture_output=True,
        text=True,
    )
    if keychain.returncode == 0:
        plain = keychain.stdout.strip()

if not plain and b64:
    try:
        plain = base64.b64decode(b64, validate=False).decode("utf-8").strip()
    except Exception:
        print("Fehler: REISEN_GITHUB_ISSUES_TOKEN_BASE64 ist kein gültiges Base64.", file=sys.stderr)
        sys.exit(1)

if not plain:
    if require:
        print(
            "Fehler: REISEN_GITHUB_ISSUES_TOKEN_BASE64 fehlt (Release erfordert das Issue-Token).",
            file=sys.stderr,
        )
        sys.exit(1)
    write_from_stub()
    print("OK: GitHub-Issue-Token nicht gesetzt — leere Payload aus Stub.", file=sys.stderr)
    sys.exit(0)

key = secrets.token_bytes(32)
raw = plain.encode("utf-8")
xored = bytes(byte ^ key[index % len(key)] for index, byte in enumerate(raw))


def fmt(data: bytes) -> str:
    return ", ".join(f"0x{byte:02X}" for byte in data)


content = (
    "enum GitHubIssueTokenPayload {\n"
    f"    static let bytes: [UInt8] = [{fmt(xored)}]\n"
    f"    static let key: [UInt8] = [{fmt(key)}]\n"
    "}\n"
)

if plain.encode("utf-8") in content.encode("utf-8") or plain in content:
    print("Fehler: Klartext-Token in Generated-Datei.", file=sys.stderr)
    sys.exit(1)
encoded = base64.b64encode(plain.encode("utf-8")).decode("ascii")
if encoded in content:
    print("Fehler: Base64-Token in Generated-Datei.", file=sys.stderr)
    sys.exit(1)

os.makedirs(os.path.dirname(out), exist_ok=True)
with open(out, "w", encoding="utf-8") as handle:
    handle.write(content)
print("OK: GitHub-Issue-Token als XOR-Payload eingebettet.", file=sys.stderr)
PY
