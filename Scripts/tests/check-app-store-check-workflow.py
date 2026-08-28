#!/usr/bin/env python3
"""Vertrag für .github/workflows/app-store-check.yml (Store-Archive, kein Guideline-Scanner)."""

from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import NoReturn

ARCHIVE_SECRETS = (
    "REISEN_GITHUB_ISSUES_TOKEN_BASE64",
    "APP_STORE_CONNECT_API_KEY_BASE64",
    "APP_STORE_CONNECT_API_KEY_KEY_ID",
    "APP_STORE_CONNECT_API_KEY_ISSUER",
    "APPLE_TEAM_ID",
)
JOB_RE = re.compile(r"^  ([A-Za-z0-9_-]+):\s*$")
FORBIDDEN_SUBSTRINGS = (
    "appcompliance",
    "upload-artifact",
    "download-artifact",
)


class WorkflowContractError(Exception):
    pass


def die(message: str) -> NoReturn:
    print(f"Fehler: {message}", file=sys.stderr)
    raise SystemExit(1)


def fail(message: str) -> NoReturn:
    raise WorkflowContractError(message)


def job_ids(text: str) -> list[str]:
    in_jobs = False
    ids: list[str] = []
    for line in text.splitlines():
        if line.startswith("jobs:"):
            in_jobs = True
            continue
        if not in_jobs:
            continue
        match = JOB_RE.match(line)
        if match:
            ids.append(match.group(1))
    return ids


def job_block(text: str, job_id: str) -> str:
    lines = text.splitlines()
    in_jobs = False
    start: int | None = None
    for index, line in enumerate(lines):
        if line.startswith("jobs:"):
            in_jobs = True
            continue
        if not in_jobs:
            continue
        match = JOB_RE.match(line)
        if not match:
            continue
        if start is not None:
            return "\n".join(lines[start:index])
        if match.group(1) == job_id:
            start = index
    if start is None:
        fail(f"Job {job_id} fehlt in app-store-check.yml.")
    return "\n".join(lines[start:])


def require_secret_env(block: str, name: str) -> None:
    needle = f"{name}: ${{{{ secrets.{name} }}}}"
    if needle not in block:
        fail(f"App Store Check muss {name} an das Store-Archive durchreichen.")


def check_workflow_text(text: str) -> None:
    if "ios-archive-appstore.sh" not in text:
        fail("App Store Check muss Scripts/ios-archive-appstore.sh verwenden (nur Store-Target).")
    if "ios-archive-adhoc.sh" in text:
        fail("App Store Check darf das Private-Archive nicht bauen.")
    if "--mode store --ipa" not in text:
        fail("App Store Check muss das Store-IPA isolieren (--mode store --ipa).")
    if "ios-validate-appstore.sh" not in text:
        fail("App Store Check muss das Store-IPA mit ios-validate-appstore.sh gegen Apple validieren.")

    lowered = text.lower()
    for needle in FORBIDDEN_SUBSTRINGS:
        if needle in lowered:
            fail(
                "App Store Check darf keinen Drittanbieter-Guideline-Scan und "
                f"kein IPA-Artifact enthalten ({needle})."
            )

    ids = job_ids(text)
    if ids != ["archive"]:
        fail(f"App Store Check darf nur den Job archive haben, gefunden: {ids}.")

    archive_block = job_block(text, "archive")
    for secret in ARCHIVE_SECRETS:
        require_secret_env(archive_block, secret)


def expect_fail(text: str, label: str) -> None:
    try:
        check_workflow_text(text)
    except WorkflowContractError:
        return
    die(f"Self-Check {label} hätte ablehnen müssen.")


def self_check() -> None:
    sample = (
        "jobs:\n"
        "  archive:\n"
        "    runs-on: ubuntu-latest\n"
        "  scan:\n"
        "    runs-on: ubuntu-latest\n"
    )
    if job_ids(sample) != ["archive", "scan"]:
        die("Self-Check job_ids fehlgeschlagen.")
    if "runs-on: ubuntu-latest" not in job_block(sample, "archive"):
        die("Self-Check job_block archive fehlgeschlagen.")

    secrets_env = "\n".join(
        f"          {name}: ${{{{ secrets.{name} }}}}" for name in ARCHIVE_SECRETS
    )
    valid = (
        "jobs:\n"
        "  archive:\n"
        "    runs-on: xcode-27\n"
        "    steps:\n"
        "      - run: |\n"
        "          bash ./Scripts/ios-archive-appstore.sh\n"
        "          bash ./Scripts/ios-verify-binary-isolation.sh --mode store --ipa foo.ipa\n"
        "          bash ./Scripts/ios-validate-appstore.sh foo.ipa\n"
        "        env:\n"
        f"{secrets_env}\n"
    )
    check_workflow_text(valid)
    expect_fail(valid + "      - uses: actions/upload-artifact@v4\n", "upload-artifact")
    expect_fail(valid.replace("  archive:", "  scan:"), "nur Job archive")
    expect_fail(valid + "          token: ${{ secrets.APPCOMPLIANCE_TOKEN }}\n", "appcompliance")


def check_workflow(path: Path) -> None:
    try:
        check_workflow_text(path.read_text(encoding="utf-8"))
    except WorkflowContractError as exc:
        die(str(exc))


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("Usage: check-app-store-check-workflow.py <workflow.yml>")
    self_check()
    check_workflow(Path(sys.argv[1]))


if __name__ == "__main__":
    main()
