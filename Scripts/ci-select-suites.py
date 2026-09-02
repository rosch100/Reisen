#!/usr/bin/env python3
"""Fail-closed Suite-Selection für Reisen CI (Detect-Job SSOT)."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

_SCRIPTS_DIR = Path(__file__).resolve().parent
if str(_SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS_DIR))

from ci_suite_constants import ALL_SUITES, SUITE_OUTPUT_KEYS  # noqa: E402

HARNESS_EXACT: frozenset[str] = frozenset(
    {
        ".github/workflows/ci.yml",
        "Scripts/ci-select-suites.py",
        "Scripts/ci-enforce-suite-gate.py",
        "Scripts/ci_suite_constants.py",
        "Scripts/ci-test.sh",
        "Scripts/generate-ios-project.sh",
        "project.yml",
        "Package.swift",
    }
)

HARNESS_PREFIXES: tuple[str, ...] = (
    "Scripts/ios-",
    "Scripts/macos-ui",
)

DOC_EXACT: frozenset[str] = frozenset(
    {
        "LICENSE",
        "CODE_OF_CONDUCT.md",
        "SECURITY.md",
        "CONTRIBUTING.md",
        "README.md",
        "AGENTS.md",
        "AI_POLICY.md",
        "CLAUDE.md",
        "GEMINI.md",
    }
)

SWIFTPM_SOURCE_PREFIXES: tuple[str, ...] = (
    "Sources/ReisenDomain/",
    "Sources/ReisenData/",
    "Sources/ReisenDiagnostics/",
    "Sources/ReisenProviders/",
    "Sources/ReisenAppCore/",
    "Sources/ReisenPasteImport/",
    "Sources/ReisenProviderSync/",
    "Sources/ReisenCheck24/",
    "Sources/ReisenOpodo/",
    "Sources/ReisenBookingCom/",
    "Sources/ReisenAirbnb/",
    "Sources/ReisenGetYourGuide/",
    "Sources/ReisenTraveloka/",
    "Sources/ReisenBilligerMietwagen/",
    "Sources/ReisenCrashSignal/",
)

SWIFTPM_TEST_PREFIXES: tuple[str, ...] = (
    "Tests/ReisenDomainTests/",
    "Tests/ReisenDataTests/",
    "Tests/ReisenDiagnosticsTests/",
    "Tests/ReisenProvidersTests/",
    "Tests/ReisenAppCoreTests/",
    "Tests/ReisenPasteImportTests/",
    "Tests/ReisenProviderSyncTests/",
    "Tests/ReisenCheck24Tests/",
    "Tests/ReisenOpodoTests/",
    "Tests/ReisenBookingComTests/",
    "Tests/ReisenAirbnbTests/",
    "Tests/ReisenGetYourGuideTests/",
    "Tests/ReisenTravelokaTests/",
    "Tests/ReisenBilligerMietwagenTests/",
    "Tests/ReisenSharedUITests/",
)


def is_docs_path(path: str) -> bool:
    if path.startswith("docs/"):
        return True
    name = Path(path).name
    if path == name and name in DOC_EXACT:
        return True
    if path == name and name.endswith(".md"):
        return True
    return False


def is_harness_path(path: str) -> bool:
    if path in HARNESS_EXACT:
        return True
    return any(path.startswith(prefix) for prefix in HARNESS_PREFIXES)


def map_path_to_suites(path: str) -> set[str] | str:
    """Return suite names, 'full', or 'docs'."""
    if is_harness_path(path):
        return "full"
    if is_docs_path(path):
        return "docs"
    if path == "Scripts/ios-verify-binary-isolation.sh":
        return {"suite-ios-release"}
    if path.startswith("Sources/ReisenSharedUI/"):
        return set(ALL_SUITES)
    if path.startswith("Sources/Reisen/"):
        return {"suite-swiftpm", "suite-macos-ui"}
    if any(path.startswith(p) for p in SWIFTPM_SOURCE_PREFIXES):
        return {"suite-swiftpm"}
    if any(path.startswith(p) for p in SWIFTPM_TEST_PREFIXES):
        return {"suite-swiftpm"}
    if path.startswith("Apps/ReiseniOS/") or path.startswith("Apps/ReiseniOSPrivate/"):
        return {"suite-ios-sim", "suite-ios-release"}
    if path.startswith("Tests/ReiseniOS"):
        return {"suite-ios-sim", "suite-ios-release"}
    if path.startswith("Apps/Shared/") or path.startswith("Tests/ReisenMacUITests/"):
        return {"suite-macos-ui"}
    if path.startswith(("Sources/", "Apps/", "Tests/", "Scripts/", ".github/")):
        return "full"
    return "full"


def git_diff_names(repo: Path, base: str, head: str = "HEAD") -> list[str]:
    proc = subprocess.run(
        ["git", "-C", str(repo), "diff", "--name-only", f"{base}...{head}"],
        check=False,
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"git diff fehlgeschlagen: {proc.stderr.strip()}")
    return [line.strip() for line in proc.stdout.splitlines() if line.strip()]


def select_suites(
    *,
    changed_files: list[str],
    baselines: dict[str, str | None],
    force_full: bool,
    push_to_default: bool,
) -> dict[str, Any]:
    if force_full or push_to_default:
        reason = "harness" if force_full and not push_to_default else "push-master"
        if force_full and any(is_harness_path(p) for p in changed_files):
            reason = "harness"
        elif force_full and os.environ.get("REISEN_CI_SELECTION", "").strip().lower() == "full":
            reason = "force-env"
        return _full_result(baselines, reason)

    must_run = {suite for suite, sha in baselines.items() if not sha}
    if len(must_run) == len(ALL_SUITES):
        return _full_result(baselines, "no-last-green")

    if not changed_files and not must_run:
        return _full_result(baselines, "unmapped")

    selected: set[str] = set(must_run)
    saw_docs_only = True
    for path in changed_files:
        mapped = map_path_to_suites(path)
        if mapped == "full":
            return _full_result(baselines, "harness" if is_harness_path(path) else "unmapped")
        if mapped == "docs":
            continue
        saw_docs_only = False
        assert isinstance(mapped, set)
        selected |= mapped

    if saw_docs_only and not must_run and changed_files:
        return {
            "mode": "empty-allowed",
            "reason": "docs-only",
            "baselines": baselines,
            "suites": [],
            "skipped": list(ALL_SUITES),
            "changedFilesSample": changed_files[:50],
        }

    if not selected:
        return _full_result(baselines, "unmapped")

    skipped = [s for s in ALL_SUITES if s not in selected]
    return {
        "mode": "affected",
        "reason": "no-last-green" if must_run else "affected",
        "baselines": baselines,
        "suites": [s for s in ALL_SUITES if s in selected],
        "skipped": skipped,
        "changedFilesSample": changed_files[:50],
    }


def _full_result(baselines: dict[str, str | None], reason: str) -> dict[str, Any]:
    return {
        "mode": "full",
        "reason": reason,
        "baselines": baselines,
        "suites": list(ALL_SUITES),
        "skipped": [],
        "changedFilesSample": [],
    }


def fetch_last_green_baselines(
    *,
    token: str,
    repo: str,
    branch: str,
    workflow_file: str = "ci.yml",
) -> dict[str, str | None]:
    baselines: dict[str, str | None] = {suite: None for suite in ALL_SUITES}
    remaining = set(ALL_SUITES)
    runs = _api_json(
        token,
        f"https://api.github.com/repos/{repo}/actions/workflows/{urllib.parse.quote(workflow_file)}/runs"
        f"?branch={urllib.parse.quote(branch)}&status=completed&per_page=30",
    )
    for run in runs.get("workflow_runs", []):
        if run.get("conclusion") != "success":
            continue
        run_id = run["id"]
        head_sha = run.get("head_sha")
        if not isinstance(head_sha, str) or not head_sha:
            continue
        jobs_payload = _api_json(
            token,
            f"https://api.github.com/repos/{repo}/actions/runs/{run_id}/jobs?per_page=50",
        )
        for job in jobs_payload.get("jobs", []):
            name = job.get("name")
            if name in remaining and job.get("conclusion") == "success":
                baselines[name] = head_sha
                remaining.remove(name)
        if not remaining:
            break
    return baselines


def _api_json(token: str, url: str) -> dict[str, Any]:
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "reisen-ci-select-suites",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            payload = json.load(response)
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"GitHub API HTTP {exc.code}: {body}") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"GitHub API unreachable: {exc}") from exc
    if not isinstance(payload, dict):
        raise RuntimeError("GitHub API: unerwartetes JSON")
    return payload


def write_github_outputs(selection: dict[str, Any], output_path: Path) -> None:
    lines = [
        f"mode={selection['mode']}",
        f"reason={selection['reason']}",
    ]
    selected = set(selection["suites"])
    for suite, key in SUITE_OUTPUT_KEYS.items():
        lines.append(f"{key}={'true' if suite in selected else 'false'}")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("a", encoding="utf-8") as handle:
        handle.write("\n".join(lines) + "\n")


def build_changed_files(
    *,
    repo: Path,
    baselines: dict[str, str | None],
    explicit_files: list[str] | None,
) -> list[str]:
    if explicit_files is not None:
        return list(explicit_files)
    shas = [sha for sha in baselines.values() if sha]
    if not shas:
        return git_diff_names(repo, "origin/master") if _ref_exists(repo, "origin/master") else []
    changed: set[str] = set()
    for sha in shas:
        changed.update(git_diff_names(repo, sha))
    return sorted(changed)


def _ref_exists(repo: Path, ref: str) -> bool:
    proc = subprocess.run(
        ["git", "-C", str(repo), "rev-parse", "--verify", ref],
        check=False,
        capture_output=True,
        text=True,
    )
    return proc.returncode == 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Reisen CI Suite-Selection")
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--out", type=Path, required=True, help="selection.json path")
    parser.add_argument("--github-output", type=Path, default=None)
    parser.add_argument("--branch", default=os.environ.get("REISEN_CI_BRANCH", ""))
    parser.add_argument("--event-name", default=os.environ.get("GITHUB_EVENT_NAME", ""))
    parser.add_argument("--ref-name", default=os.environ.get("GITHUB_REF_NAME", ""))
    parser.add_argument("--repo-slug", default=os.environ.get("GITHUB_REPOSITORY", ""))
    parser.add_argument("--changed-file", action="append", default=None)
    parser.add_argument(
        "--baseline",
        action="append",
        default=None,
        metavar="SUITE=SHA",
        help="Override Last-Green (tests / offline)",
    )
    parser.add_argument("--skip-api", action="store_true")
    args = parser.parse_args(argv)

    force_env = os.environ.get("REISEN_CI_SELECTION", "").strip().lower() == "full"
    push_to_default = args.event_name == "push" and (
        args.ref_name == "master" or os.environ.get("GITHUB_REF") == "refs/heads/master"
    )

    baselines: dict[str, str | None] = {suite: None for suite in ALL_SUITES}
    api_error = False
    if args.baseline:
        for item in args.baseline:
            if "=" not in item:
                print(f"Fehler: --baseline erwartet SUITE=SHA, got {item}", file=sys.stderr)
                return 2
            suite, sha = item.split("=", 1)
            if suite not in baselines:
                print(f"Fehler: unbekannte Suite {suite}", file=sys.stderr)
                return 2
            baselines[suite] = sha or None
    elif not args.skip_api and not force_env and not push_to_default:
        token = os.environ.get("GITHUB_TOKEN", "").strip()
        branch = args.branch or os.environ.get("GITHUB_HEAD_REF") or args.ref_name
        if not token or not args.repo_slug or not branch:
            print(
                "Hinweis: Last-Green-API übersprungen (Token/Repo/Branch fehlen) → full",
                file=sys.stderr,
            )
            api_error = True
        else:
            try:
                baselines = fetch_last_green_baselines(
                    token=token,
                    repo=args.repo_slug,
                    branch=branch,
                )
            except RuntimeError as exc:
                print(f"Hinweis: Last-Green-API fehlgeschlagen → full: {exc}", file=sys.stderr)
                api_error = True

    if api_error:
        selection = _full_result(baselines, "api-error")
    else:
        try:
            changed = build_changed_files(
                repo=args.repo,
                baselines=baselines,
                explicit_files=args.changed_file,
            )
        except RuntimeError as exc:
            print(f"Fehler: {exc}", file=sys.stderr)
            return 1
        force_full = force_env or any(is_harness_path(p) for p in changed)
        selection = select_suites(
            changed_files=changed,
            baselines=baselines,
            force_full=force_full,
            push_to_default=push_to_default,
        )

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(selection, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(
        f"reisen-ci-selection: mode={selection['mode']} reason={selection['reason']} "
        f"suites={selection['suites']} skipped={selection['skipped']}",
        file=sys.stderr,
    )
    output_path = args.github_output
    if output_path is None and os.environ.get("GITHUB_OUTPUT"):
        output_path = Path(os.environ["GITHUB_OUTPUT"])
    if output_path is not None:
        write_github_outputs(selection, output_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
