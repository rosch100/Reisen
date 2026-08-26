#!/usr/bin/env bash
# Speichert das GitHub-Issues-PAT lokal persistent (Datei + Keychain).
# Liest die macOS-Zwischenablage. Token wird niemals geloggt.
set -euo pipefail
set +x

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export REISEN_STORE_ROOT="$ROOT"

python3 <<'PY'
import os
import shlex
import stat
import subprocess
import sys

root = os.environ["REISEN_STORE_ROOT"]
secrets_dir = os.path.join(root, "Secrets")
token_path = os.path.join(secrets_dir, "github-issues.token")
env_path = os.path.join(secrets_dir, "github-issues.env")

raw = subprocess.check_output(["pbpaste"])
token = raw.decode("utf-8").strip().replace("\r", "")
ok = token.startswith("github_pat_") or token.startswith("ghp_")
print(f"prefix_ok={ok}")
print(f"length={len(token)}")
if not ok or len(token) < 20:
    print("Fehler: Zwischenablage enthält kein GitHub-PAT.", file=sys.stderr)
    sys.exit(2)

os.makedirs(secrets_dir, mode=0o700, exist_ok=True)
with open(token_path, "w", encoding="utf-8") as handle:
    handle.write(token + "\n")
os.chmod(token_path, stat.S_IRUSR | stat.S_IWUSR)

quoted = shlex.quote(token)
with open(env_path, "w", encoding="utf-8") as handle:
    handle.write("# Lokal, nicht committen.\n")
    handle.write(f"export REISEN_GITHUB_ISSUES_TOKEN={quoted}\n")
os.chmod(env_path, stat.S_IRUSR | stat.S_IWUSR)

add = subprocess.run(
    [
        "security",
        "add-generic-password",
        "-a",
        "reisen",
        "-s",
        "reisen.github-issues-token",
        "-U",
        "-w",
        token,
    ],
    capture_output=True,
    text=True,
)
if add.returncode != 0:
    print("Fehler: Keychain-Eintrag konnte nicht geschrieben werden.", file=sys.stderr)
    if add.stderr:
        print(add.stderr.strip(), file=sys.stderr)
    sys.exit(add.returncode)

verify = subprocess.run(
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
if verify.returncode != 0 or verify.stdout.strip() != token:
    print("Fehler: Keychain-Eintrag weicht ab.", file=sys.stderr)
    sys.exit(1)

on_disk = open(token_path, encoding="utf-8").read().strip()
if on_disk != token:
    print("Fehler: Token-Datei weicht ab.", file=sys.stderr)
    sys.exit(1)

print("stored=file+keychain")
print("file_mode=600")
PY
