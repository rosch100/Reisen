#!/usr/bin/env bash
# GitHub Actions → Issue-Dev Forward (HMAC + Envelope + optional Grok wake).
# Secrets niemals loggen. Kein set -x.
set -euo pipefail
set +x

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

EVENT_NAME="${GITHUB_EVENT_NAME:-}"
EVENT_PATH="${GITHUB_EVENT_PATH:-}"
if [[ -z "$EVENT_NAME" || -z "$EVENT_PATH" || ! -f "$EVENT_PATH" ]]; then
  echo "GITHUB_EVENT_NAME/PATH fehlt" >&2
  exit 1
fi

PAYLOAD="$(cat "$EVENT_PATH")"
# GitHub liefert Signatur nur bei Repo-Webhooks; Actions-Pfad: SkipSignature wenn Secret fehlt und Event aus Actions kommt.
SIG="${ISSUE_DEV_RECEIVED_SIGNATURE:-}"

# Prefer vendored CI scripts if present (optional submodule/path); else use python fallback minimal wake.
CI_SCRIPTS="${ISSUE_DEV_CI_SCRIPTS:-}"
if [[ -n "$CI_SCRIPTS" && -f "$CI_SCRIPTS/Invoke-IssueDevForwardWake.ps1" ]]; then
  EXTRA=()
  if [[ -z "${ISSUE_DEV_WEBHOOK_SECRET:-}" ]]; then
    EXTRA+=(-SkipSignature)
  fi
  if [[ -z "${ISSUE_DEV_GROK_WEBHOOK_URL:-}" ]]; then
    EXTRA+=(-SkipGrokWake)
  fi
  exec pwsh -NoProfile -File "$CI_SCRIPTS/Invoke-IssueDevForwardWake.ps1" \
    -HostName github \
    -EventName "$EVENT_NAME" \
    -PayloadJson "$PAYLOAD" \
    -SignatureHeader "$SIG" \
    -DeliveryToken "${GITHUB_RUN_ID:-manual}-${GITHUB_RUN_ATTEMPT:-1}" \
    "${EXTRA[@]}"
fi

# Minimal Python forwarder (no pwsh on runner required for wake POST)
python3 - "$EVENT_NAME" "$EVENT_PATH" <<'PY'
import hashlib, hmac, json, os, pathlib, sys, urllib.request

event_name, event_path = sys.argv[1], sys.argv[2]
payload = pathlib.Path(event_path).read_text(encoding="utf-8")
secret = os.environ.get("ISSUE_DEV_WEBHOOK_SECRET", "")
sig = os.environ.get("ISSUE_DEV_RECEIVED_SIGNATURE", "")
if secret:
    if not sig.startswith("sha256="):
        print("missing signature", file=sys.stderr)
        sys.exit(1)
    digest = hmac.new(secret.encode(), payload.encode(), hashlib.sha256).hexdigest()
    if not hmac.compare_digest(sig[7:], digest):
        print("bad signature", file=sys.stderr)
        sys.exit(1)

data = json.loads(payload)
repo = data.get("repository") or {}
full = repo.get("full_name") or "rosch100/Reisen"
owner, name = full.split("/", 1)
issue = data.get("issue") or {}
comment = data.get("comment") or {}
labels = []
for lab in issue.get("labels") or []:
    if isinstance(lab, dict) and lab.get("name"):
        labels.append(lab["name"])
kind = "manual_wake"
if event_name == "issues":
    kind = "issue_opened" if data.get("action") == "opened" else "issue_labeled"
elif event_name == "issue_comment":
    kind = "issue_comment"
elif event_name == "pull_request":
    kind = "pull_request"
elif event_name == "workflow_run":
    kind = "ci_completed"
elif event_name == "repository_dispatch":
    kind = "manual_wake"

run_id = os.environ.get("GITHUB_RUN_ID", "local")
attempt = os.environ.get("GITHUB_RUN_ATTEMPT", "1")
delivery_id = f"github/{owner}/{name}/{kind}/{run_id}-{attempt}"
envelope = {
    "deliveryId": delivery_id,
    "host": "github",
    "owner": owner,
    "repo": name,
    "kind": kind,
    "issueNumber": issue.get("number"),
    "prNumber": (data.get("pull_request") or {}).get("number"),
    "commentBody": comment.get("body"),
    "labels": labels,
    "skillHint": (
        "bugfix" if "kind/error" in labels else
        "feature-dev" if "kind/feature" in labels else None
    ),
    "htmlUrl": issue.get("html_url") or (data.get("pull_request") or {}).get("html_url"),
}

inbox = pathlib.Path(os.environ.get("ISSUE_DEV_INBOX_DIR", "/tmp/issue-dev-inbox"))
inbox.mkdir(parents=True, exist_ok=True)
seen = inbox / "seen"
seen.mkdir(exist_ok=True)
safe = delivery_id.replace("/", "_")
seen_file = seen / safe
if seen_file.exists():
    print(json.dumps({"skipped": True, "reason": "duplicate"}))
    sys.exit(0)
out = inbox / f"{safe}.json"
out.write_text(json.dumps(envelope, indent=2), encoding="utf-8")
seen_file.write_text(delivery_id, encoding="utf-8")

url = os.environ.get("ISSUE_DEV_GROK_WEBHOOK_URL", "")
key = os.environ.get("ISSUE_DEV_GROK_WEBHOOK_KEY", "")
woke = False
if url:
    req = urllib.request.Request(
        url,
        data=json.dumps({"deliveryId": delivery_id, "path": str(out)}).encode(),
        headers={"Content-Type": "application/json", **({"Authorization": f"Bearer {key}"} if key else {})},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            resp.read()
        woke = True
    except Exception as exc:
        print(f"grok wake failed: {exc}", file=sys.stderr)

print(json.dumps({"skipped": False, "deliveryId": delivery_id, "path": str(out), "wokeGrok": woke}))
PY
