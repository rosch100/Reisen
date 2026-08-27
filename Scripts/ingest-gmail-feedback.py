#!/usr/bin/env python3
"""Gmail API (OAuth) → GitHub Issues (kind/feedback, source/email).

Muss GitHubRepository.feedbackEmail entsprechen. Secrets nie loggen.
"""
from __future__ import annotations

import argparse
import base64
import email
import hashlib
import html
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from email.header import decode_header, make_header
from email.message import Message
from typing import Any

# SSOT mit Sources/ReisenDomain/Settings/GitHubRepository.swift feedbackEmail
DEFAULT_FEEDBACK_EMAIL = "reisenapp100@gmail.com"
DEFAULT_REPO = "rosch100/Reisen"
MAX_MAILS_PER_RUN = 20
TITLE_PREFIX = "[Feedback]"
MAX_SUBJECT = 80
LABELS = ["kind/feedback", "source/email"]
API_VERSION = "2022-11-28"
USER_AGENT = "reisen-gmail-feedback-ingress"
TOKEN_URL = "https://oauth2.googleapis.com/token"
GMAIL_API = "https://gmail.googleapis.com/gmail/v1/users/me"


def log(message: str) -> None:
    print(message, file=sys.stderr)


def decode_header_value(raw: str | None) -> str:
    if not raw:
        return ""
    return str(make_header(decode_header(raw)))


def html_to_text(value: str) -> str:
    stripped = re.sub(r"(?is)<(script|style).*?>.*?</\1>", " ", value)
    stripped = re.sub(r"(?i)<br\s*/?>", "\n", stripped)
    stripped = re.sub(r"(?i)</p>", "\n\n", stripped)
    stripped = re.sub(r"<[^>]+>", " ", stripped)
    return html.unescape(re.sub(r"[ \t]+\n", "\n", stripped)).strip()


def part_payload_text(part: Message) -> str:
    payload = part.get_payload(decode=True)
    if not isinstance(payload, (bytes, bytearray)):
        return ""
    charset = part.get_content_charset() or "utf-8"
    try:
        return payload.decode(charset, errors="replace")
    except LookupError:
        return payload.decode("utf-8", errors="replace")


def extract_body_and_attachments(message: Message) -> tuple[str, list[str]]:
    attachments: list[str] = []
    plain_parts: list[str] = []
    html_parts: list[str] = []

    if message.is_multipart():
        for part in message.walk():
            disposition = (part.get_content_disposition() or "").lower()
            filename = part.get_filename()
            if disposition == "attachment" or filename:
                attachments.append(decode_header_value(filename) or "unnamed")
                continue
            content_type = part.get_content_type()
            if content_type == "text/plain":
                plain_parts.append(part_payload_text(part))
            elif content_type == "text/html":
                html_parts.append(part_payload_text(part))
    else:
        content_type = message.get_content_type()
        text = part_payload_text(message)
        if content_type == "text/html":
            html_parts.append(text)
        else:
            plain_parts.append(text)

    body = "\n\n".join(part.strip() for part in plain_parts if part.strip())
    if not body:
        body = "\n\n".join(html_to_text(part) for part in html_parts if part.strip())
    return body.strip(), attachments


def email_id_hash(message_id: str) -> str:
    return hashlib.sha256(message_id.encode("utf-8")).hexdigest()


def synthetic_message_id(from_addr: str, date: str, subject: str) -> str:
    seed = f"{from_addr}\n{date}\n{subject}"
    return f"synthetic-{hashlib.sha256(seed.encode('utf-8')).hexdigest()}"


def issue_title(subject: str) -> str:
    summary = re.sub(r"\s+", " ", subject).strip() or "(kein Betreff)"
    return f"{TITLE_PREFIX} {summary[:MAX_SUBJECT]}"


def issue_body(
    *,
    from_addr: str,
    date: str,
    subject: str,
    body: str,
    attachments: list[str],
    email_hash: str,
) -> str:
    attachment_lines = ", ".join(attachments) if attachments else "—"
    text = body.strip() or "(leerer Mailtext)"
    return (
        "## Zusammenfassung\n"
        f"{subject.strip() or '(kein Betreff)'}\n\n"
        "## Diagnose\n"
        "| Feld | Wert |\n"
        "| --- | --- |\n"
        "| Art | feedback |\n"
        "| Meldeweg | E-Mail |\n"
        f"| Von | {from_addr or '—'} |\n"
        f"| Datum | {date or '—'} |\n"
        f"| Anhänge | {attachment_lines} |\n\n"
        "## Fehler\n"
        "```\n"
        f"{text}\n"
        "```\n\n"
        f"reisen-email-id: `{email_hash}`\n"
        f"<!-- reisen-email-id: {email_hash} -->\n"
    )


def parsed_from_message(message: Message) -> dict[str, Any]:
    subject = decode_header_value(message.get("Subject"))
    from_addr = decode_header_value(message.get("From"))
    date = decode_header_value(message.get("Date"))
    message_id = (message.get("Message-ID") or message.get("Message-Id") or "").strip()
    if not message_id:
        message_id = synthetic_message_id(from_addr, date, subject)
    body, attachments = extract_body_and_attachments(message)
    email_hash = email_id_hash(message_id)
    return {
        "message_id": message_id,
        "email_hash": email_hash,
        "from": from_addr,
        "date": date,
        "subject": subject,
        "body": body,
        "attachments": attachments,
        "title": issue_title(subject),
        "issue_body": issue_body(
            from_addr=from_addr,
            date=date,
            subject=subject,
            body=body,
            attachments=attachments,
            email_hash=email_hash,
        ),
    }


def b64url_decode(data: str) -> bytes:
    padded = data + "=" * ((4 - len(data) % 4) % 4)
    return base64.urlsafe_b64decode(padded.encode("ascii"))


def parsed_from_gmail_resource(resource: dict[str, Any]) -> dict[str, Any]:
    raw = resource.get("raw")
    if not isinstance(raw, str) or not raw:
        log("Gmail-API Message ohne raw")
        raise RuntimeError("gmail raw missing")
    return parsed_from_message(email.message_from_bytes(b64url_decode(raw)))


def oauth_credentials_from_env() -> dict[str, str] | None:
    client_id = os.environ.get("REISEN_GMAIL_OAUTH_CLIENT_ID", "").strip()
    client_secret = os.environ.get("REISEN_GMAIL_OAUTH_CLIENT_SECRET", "").strip()
    refresh_token = os.environ.get("REISEN_GMAIL_OAUTH_REFRESH_TOKEN", "").strip()
    if not client_id or not client_secret or not refresh_token:
        return None
    return {
        "client_id": client_id,
        "client_secret": client_secret,
        "refresh_token": refresh_token,
    }


def require_mailbox(actual: str, expected: str) -> None:
    if actual.casefold() != expected.casefold():
        log("Gmail-Konto entspricht nicht der Feedback-Adresse")
        raise RuntimeError("gmail mailbox mismatch")


def github_request(token: str, method: str, url: str, payload: dict[str, Any] | None = None) -> Any:
    data = None
    headers = {
        "Accept": "application/vnd.github+json",
        "Authorization": f"Bearer {token}",
        "X-GitHub-Api-Version": API_VERSION,
        "User-Agent": USER_AGENT,
    }
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            raw = response.read()
            if not raw:
                return {}
            return json.loads(raw.decode("utf-8"))
    except urllib.error.HTTPError as error:
        log(f"Issues-API Status {error.code}")
        raise


def gmail_request(
    access_token: str,
    method: str,
    url: str,
    payload: dict[str, Any] | None = None,
) -> Any:
    data = None
    headers = {
        "Authorization": f"Bearer {access_token}",
        "User-Agent": USER_AGENT,
    }
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            raw = response.read()
            if not raw:
                return {}
            return json.loads(raw.decode("utf-8"))
    except urllib.error.HTTPError as error:
        log(f"Gmail-API Status {error.code}")
        raise


def refresh_access_token(creds: dict[str, str]) -> str:
    body = urllib.parse.urlencode(
        {
            "client_id": creds["client_id"],
            "client_secret": creds["client_secret"],
            "refresh_token": creds["refresh_token"],
            "grant_type": "refresh_token",
        }
    ).encode("utf-8")
    request = urllib.request.Request(
        TOKEN_URL,
        data=body,
        headers={
            "Content-Type": "application/x-www-form-urlencoded",
            "User-Agent": USER_AGENT,
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            decoded = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        log(f"Gmail-OAuth Token-Refresh Status {error.code}")
        raise
    token = decoded.get("access_token") if isinstance(decoded, dict) else None
    if not isinstance(token, str) or not token:
        log("Gmail-OAuth Token-Refresh ohne access_token")
        raise RuntimeError("oauth access_token missing")
    return token


def search_existing_issue(token: str, repo: str, email_hash: str) -> int | None:
    query = f"repo:{repo} is:issue in:body reisen-email-id:{email_hash}"
    url = "https://api.github.com/search/issues?" + urllib.parse.urlencode({"q": query})
    decoded = github_request(token, "GET", url)
    items = decoded.get("items") if isinstance(decoded, dict) else None
    if not items:
        return None
    number = items[0].get("number")
    return int(number) if number is not None else None


def create_issue(token: str, repo: str, title: str, body: str) -> int:
    url = f"https://api.github.com/repos/{repo}/issues"
    decoded = github_request(
        token,
        "POST",
        url,
        {"title": title, "body": body, "labels": LABELS},
    )
    number = decoded.get("number")
    if number is None:
        log("Issues-API Status ohne Issue-Nummer")
        raise RuntimeError("create issue missing number")
    return int(number)


def message_url(mail_id: str, suffix: str = "") -> str:
    quoted = urllib.parse.quote(mail_id, safe="")
    return f"{GMAIL_API}/messages/{quoted}{suffix}"


def mark_read(access_token: str, mail_id: str) -> None:
    gmail_request(
        access_token,
        "POST",
        message_url(mail_id, "/modify"),
        {"removeLabelIds": ["UNREAD"]},
    )


def ingest_unread(
    *,
    creds: dict[str, str],
    expected_address: str,
    token: str,
    repo: str,
) -> int:
    access_token = refresh_access_token(creds)
    profile = gmail_request(access_token, "GET", f"{GMAIL_API}/profile")
    actual = profile.get("emailAddress") if isinstance(profile, dict) else None
    if not isinstance(actual, str) or not actual:
        log("Gmail-Profil ohne Adresse")
        raise RuntimeError("gmail profile missing email")
    require_mailbox(actual, expected_address)

    listed = gmail_request(
        access_token,
        "GET",
        f"{GMAIL_API}/messages?"
        + urllib.parse.urlencode(
            {"q": "is:unread in:inbox", "maxResults": MAX_MAILS_PER_RUN}
        ),
    )
    messages = listed.get("messages") if isinstance(listed, dict) else None
    if not messages:
        return 0

    created = 0
    for item in messages[:MAX_MAILS_PER_RUN]:
        mail_id = item.get("id") if isinstance(item, dict) else None
        if not isinstance(mail_id, str) or not mail_id:
            log("Gmail-API Message ohne id")
            raise RuntimeError("gmail message id missing")
        resource = gmail_request(
            access_token,
            "GET",
            message_url(mail_id) + "?" + urllib.parse.urlencode({"format": "raw"}),
        )
        if not isinstance(resource, dict):
            log("Gmail-API Message ohne Payload")
            raise RuntimeError("gmail message payload missing")
        parsed = parsed_from_gmail_resource(resource)
        existing = search_existing_issue(token, repo, parsed["email_hash"])
        if existing is not None:
            log(f"Duplikat übersprungen (Issue #{existing})")
            mark_read(access_token, mail_id)
            continue
        number = create_issue(token, repo, parsed["title"], parsed["issue_body"])
        mark_read(access_token, mail_id)
        log(f"Issue #{number} angelegt")
        created += 1
    return created


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Gmail-Feedback zu GitHub-Issues")
    parser.add_argument("--eml-file", help="Lokale .eml parsen (ohne Netz)")
    parser.add_argument("--dry-run", action="store_true", help="Nur JSON nach stdout")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv if argv is not None else sys.argv[1:])
    if args.eml_file:
        with open(args.eml_file, "rb") as handle:
            parsed = parsed_from_message(email.message_from_bytes(handle.read()))
        if args.dry_run:
            json.dump(parsed, sys.stdout, ensure_ascii=False, indent=2)
            sys.stdout.write("\n")
            return 0
        log("--eml-file ohne --dry-run ist nicht unterstützt")
        return 2

    creds = oauth_credentials_from_env()
    if creds is None:
        log("ingest übersprungen, Secret fehlt")
        return 0

    address = os.environ.get("REISEN_FEEDBACK_GMAIL_ADDRESS", DEFAULT_FEEDBACK_EMAIL).strip()
    token = os.environ.get("GITHUB_TOKEN", "").strip()
    repo = os.environ.get("GITHUB_REPOSITORY", DEFAULT_REPO).strip()
    if not token:
        log("GITHUB_TOKEN fehlt")
        return 1
    if not repo:
        log("GITHUB_REPOSITORY fehlt")
        return 1
    if not address:
        log("Feedback-Adresse fehlt")
        return 1

    created = ingest_unread(
        creds=creds,
        expected_address=address,
        token=token,
        repo=repo,
    )
    log(f"Fertig, {created} Issue(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
