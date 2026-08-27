#!/usr/bin/env python3
"""Job-level Vertrag für .github/workflows/app-store-check.yml."""

from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import NoReturn

FORBIDDEN_ARCHIVE_NEEDS = {"preflight", "appcompliance-secrets"}
ARCHIVE_SECRETS = (
    "REISEN_GITHUB_ISSUES_TOKEN_BASE64",
    "APP_STORE_CONNECT_API_KEY_BASE64",
    "APP_STORE_CONNECT_API_KEY_KEY_ID",
    "APP_STORE_CONNECT_API_KEY_ISSUER",
    "APPLE_TEAM_ID",
)
JOB_RE = re.compile(r"^  ([A-Za-z0-9_-]+):\s*$")
FIELD_RE = re.compile(r"^    ([A-Za-z0-9_-]+):\s*(.*)$")
LIST_ITEM_RE = re.compile(r"^\s{4,}-\s+(\S+)\s*$")
SECRETS_CONTEXT_RE = re.compile(r"(?:^|[^A-Za-z0-9_-])secrets\.")


def die(message: str) -> NoReturn:
    print(f"Fehler: {message}", file=sys.stderr)
    raise SystemExit(1)


def clean(value: str) -> str:
    return value.strip().strip("\"'")


def parse_needs(rest: str) -> tuple[list[str], bool]:
    if rest.startswith("[") and rest.endswith("]"):
        inner = rest[1:-1].strip()
        return [clean(part) for part in inner.split(",") if part.strip()], False
    if rest:
        return [clean(rest)], False
    return [], True


def job_lines(text: str, job_id: str) -> list[str]:
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
            return lines[start:index]
        if match.group(1) == job_id:
            start = index
    if start is None:
        die(f"Job {job_id} fehlt in app-store-check.yml.")
    return lines[start:]


def job_text(text: str, job_id: str) -> str:
    return "\n".join(job_lines(text, job_id))


def job_top_fields(text: str, job_id: str) -> dict[str, object]:
    """Job-level needs/if only (indent 4), not steps."""
    fields: dict[str, object] = {}
    collecting_needs = False
    for line in job_lines(text, job_id)[1:]:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        field_match = FIELD_RE.match(line)
        if field_match:
            key, rest = field_match.group(1), field_match.group(2).strip()
            collecting_needs = False
            if key == "needs":
                fields["needs"], collecting_needs = parse_needs(rest)
            elif key == "if":
                fields["if"] = rest
            continue
        if collecting_needs:
            item = LIST_ITEM_RE.match(line)
            if item:
                needs = fields.setdefault("needs", [])
                if isinstance(needs, list):
                    needs.append(clean(item.group(1)))
                continue
            collecting_needs = False
    return fields


def needs_ids(fields: dict[str, object]) -> list[str]:
    raw = fields.get("needs", [])
    if isinstance(raw, list):
        return [str(item) for item in raw]
    die("needs hat unerwarteten Typ.")


def require_need(text: str, job_id: str, need: str, label: str) -> None:
    if need not in needs_ids(job_top_fields(text, job_id)):
        die(f"Self-Check {label} fehlgeschlagen.")


def archive_needs_yaml(needs_suffix: str) -> str:
    return (
        "jobs:\n"
        "  archive:\n"
        f"    needs{needs_suffix}\n"
        "    runs-on: ubuntu-latest\n"
    )


def scan_if_yaml(condition: str) -> str:
    return (
        "jobs:\n"
        "  scan:\n"
        f"    if: {condition}\n"
        "    runs-on: ubuntu-latest\n"
    )


def self_check() -> None:
    cases = (
        (": preflight", "preflight", "scalar needs"),
        (
            ":\n      - appcompliance-secrets\n      - other",
            "appcompliance-secrets",
            "list needs",
        ),
        (": [appcompliance-secrets, other]", "appcompliance-secrets", "flow needs"),
        (
            ': ["appcompliance-secrets", "other"]',
            "appcompliance-secrets",
            "quoted flow needs",
        ),
        (
            ":\n    - appcompliance-secrets",
            "appcompliance-secrets",
            "4-space list needs",
        ),
        (
            ":\n      - 'appcompliance-secrets'",
            "appcompliance-secrets",
            "quoted list needs",
        ),
    )
    for suffix, need, label in cases:
        require_need(archive_needs_yaml(suffix), "archive", need, label)

    bad_if = str(
        job_top_fields(
            scan_if_yaml("${{ secrets.APPCOMPLIANCE_TOKEN != '' }}"),
            "scan",
        ).get("if", "")
    )
    good_if = str(
        job_top_fields(
            scan_if_yaml("needs.appcompliance-secrets.outputs.enabled == 'true'"),
            "scan",
        ).get("if", "")
    )
    if "outputs.enabled" not in good_if:
        die("Self-Check scan.if outputs.enabled fehlgeschlagen.")
    if not SECRETS_CONTEXT_RE.search(bad_if):
        die("Self-Check scan.if secrets-Condition fehlgeschlagen.")
    if SECRETS_CONTEXT_RE.search(good_if):
        die("Self-Check scan.if false-positive secrets.")


def require_secret_env(block: str, name: str) -> None:
    needle = f"{name}: ${{{{ secrets.{name} }}}}"
    if needle not in block:
        die(f"App Store Check muss {name} an das Store-Archive durchreichen.")


def check_workflow(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    if "ios-archive-appstore.sh" not in text:
        die("App Store Check muss Scripts/ios-archive-appstore.sh verwenden (nur Store-Target).")
    if "ios-archive-adhoc.sh" in text:
        die("App Store Check darf das Private-Archive nicht bauen oder scannen.")

    secrets_job = job_text(text, "appcompliance-secrets")
    if "exit 1" in secrets_job:
        die("AppCompliance-Secrets-Job darf fehlende Secrets nicht mit exit 1 abbrechen.")

    archive = job_top_fields(text, "archive")
    blocked = FORBIDDEN_ARCHIVE_NEEDS.intersection(needs_ids(archive))
    if blocked:
        die(
            "Archive Store IPA darf nicht an AppCompliance-Secrets hängen "
            f"(needs enthält {sorted(blocked)})."
        )
    archive_block = job_text(text, "archive")
    for secret in ARCHIVE_SECRETS:
        require_secret_env(archive_block, secret)

    scan_if = str(job_top_fields(text, "scan").get("if", ""))
    if "outputs.enabled" not in scan_if:
        die("AppCompliance-Scan muss per Job-Output enabled skippen (scan.if ohne outputs.enabled).")
    if SECRETS_CONTEXT_RE.search(scan_if):
        die("scan.if darf keine secrets-Condition nutzen (actionlint: secrets nicht in job if:).")

    retract = job_top_fields(text, "retract-ipa-artifact")
    retract_needs = needs_ids(retract)
    if "archive" not in retract_needs or "scan" not in retract_needs:
        die(
            "retract-ipa-artifact muss archive und scan brauchen "
            "(Artifact erst nach dem Scan bzw. Skip löschen)."
        )
    if "always()" not in str(retract.get("if", "")):
        die("retract-ipa-artifact muss bei übersprungenem Scan trotzdem laufen (if: always()).")
    if "actions/artifacts/${ARTIFACT_ID}" not in job_text(text, "retract-ipa-artifact"):
        die("App Store Check muss das Store-IPA-Artifact nach dem Scan per GitHub-API löschen.")


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("Usage: check-app-store-check-workflow.py <workflow.yml>")
    self_check()
    check_workflow(Path(sys.argv[1]))


if __name__ == "__main__":
    main()
