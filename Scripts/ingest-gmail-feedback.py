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
from email.utils import parseaddr
from typing import Any

# SSOT mit Sources/ReisenDomain/Settings/GitHubRepository.swift feedbackEmail
DEFAULT_FEEDBACK_EMAIL = "reisenapp100@gmail.com"
DEFAULT_REPO = "rosch100/Reisen"
MAX_MAILS_PER_RUN = 20
TITLE_PREFIX = "[Feedback]"
MAX_SUBJECT = 80
LABELS = ["kind/feedback", "source/email"]
GMAIL_ID_MARKER = "issue-dev-gmail-id"
EMAIL_ID_MARKER = "reisen-email-id"
GMAIL_API_ID_PATTERN = re.compile(r"^[A-Za-z0-9_-]+$")
HTML_COMMENT_PATTERN = re.compile(r"(?is)<!--.*?-->")
OAUTH_ENV = {
    "client_id": "REISEN_GMAIL_OAUTH_CLIENT_ID",
    "client_secret": "REISEN_GMAIL_OAUTH_CLIENT_SECRET",
    "refresh_token": "REISEN_GMAIL_OAUTH_REFRESH_TOKEN",
}
# SSOT mit PasteImportFailedMailDraft.skipIngressMarker
PASTE_IMPORT_DOCUMENT_MARKER = "reisen-paste-import-document"
API_VERSION = "2022-11-28"
USER_AGENT = "reisen-gmail-feedback-ingress"
TOKEN_URL = "https://oauth2.googleapis.com/token"
GMAIL_API = "https://gmail.googleapis.com/gmail/v1/users/me"
GITHUB_API = "https://api.github.com"
HTTP_TIMEOUT_SEC = 60
EMPTY_SUBJECT = "(kein Betreff)"
EMPTY_CELL = "—"
EMPTY_MAIL_TEXT = "(leerer Mailtext)"
UNREAD_FEEDBACK_QUERY = (
    "is:unread in:inbox -in:spam -in:trash "
    "-from:accounts.google.com -from:google.com"
)
CONSUMER_GOOGLE_MAIL_DOMAINS = frozenset({"gmail.com", "googlemail.com"})


def log(message: str) -> None:
    print(message, file=sys.stderr)


def sender_email_address(from_header: str) -> str:
    _, addr = parseaddr(from_header)
    return addr.strip().casefold()


def is_automated_google_sender(from_header: str) -> bool:
    addr = sender_email_address(from_header)
    if "@" not in addr:
        return False
    _, _, domain = addr.rpartition("@")
    if domain in CONSUMER_GOOGLE_MAIL_DOMAINS:
        return False
    return domain == "google.com" or domain.endswith(".google.com")


def gmail_label_ids(resource: dict[str, Any]) -> list[str]:
    raw = resource.get("labelIds")
    if not isinstance(raw, list):
        return []
    return [label for label in raw if isinstance(label, str)]


def skip_ingest_reason(*, from_header: str, label_ids: list[str] | None) -> str | None:
    labels = {label.casefold() for label in (label_ids or [])}
    if "spam" in labels:
        return "spam"
    if "trash" in labels:
        return "trash"
    if is_automated_google_sender(from_header):
        return "automated-google"
    return None


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


def should_skip_github_issue(body: str) -> bool:
    lines = body.lstrip().splitlines()
    return bool(lines) and lines[0] == PASTE_IMPORT_DOCUMENT_MARKER


def email_id_hash(message_id: str) -> str:
    return hashlib.sha256(message_id.encode("utf-8")).hexdigest()


def synthetic_message_id(from_addr: str, date: str, subject: str) -> str:
    seed = f"{from_addr}\n{date}\n{subject}"
    return f"synthetic-{hashlib.sha256(seed.encode('utf-8')).hexdigest()}"


def sanitized_issue_field(value: str) -> str:
    if not value:
        return ""
    return HTML_COMMENT_PATTERN.sub("", value).strip()


def issue_title(subject: str) -> str:
    summary = re.sub(r"\s+", " ", sanitized_issue_field(subject)).strip() or EMPTY_SUBJECT
    return f"{TITLE_PREFIX} {summary[:MAX_SUBJECT]}"


def issue_marker(name: str, value: str) -> str:
    return f"{name}: `{value}`\n<!-- {name}: {value} -->\n"


def issue_table_cell(value: str) -> str:
    return value or EMPTY_CELL


def issue_attachment_cell(attachments: list[str]) -> str:
    names = [name for name in (sanitized_issue_field(name) for name in attachments) if name]
    return ", ".join(names) if names else EMPTY_CELL


def issue_body(
    *,
    from_addr: str,
    date: str,
    subject: str,
    body: str,
    attachments: list[str],
    email_hash: str,
    gmail_api_id: str | None = None,
) -> str:
    from_addr = sanitized_issue_field(from_addr)
    date = sanitized_issue_field(date)
    subject = sanitized_issue_field(subject)
    text = sanitized_issue_field(body) or EMPTY_MAIL_TEXT
    gmail_lines = issue_marker(GMAIL_ID_MARKER, gmail_api_id) if gmail_api_id else ""
    return (
        "## Zusammenfassung\n"
        f"{subject or EMPTY_SUBJECT}\n\n"
        "## Diagnose\n"
        "| Feld | Wert |\n"
        "| --- | --- |\n"
        "| Art | feedback |\n"
        "| Meldeweg | E-Mail |\n"
        f"| Von | {issue_table_cell(from_addr)} |\n"
        f"| Datum | {issue_table_cell(date)} |\n"
        f"| Anhänge | {issue_attachment_cell(attachments)} |\n\n"
        "## Fehler\n"
        "```\n"
        f"{text}\n"
        "```\n\n"
        f"{issue_marker(EMAIL_ID_MARKER, email_hash)}"
        f"{gmail_lines}"
    )


def normalized_gmail_api_id(value: str | None) -> str | None:
    if not isinstance(value, str):
        return None
    trimmed = value.strip()
    if not trimmed or not GMAIL_API_ID_PATTERN.fullmatch(trimmed):
        return None
    return trimmed


def require_gmail_api_id(*values: object) -> str:
    found: list[str] = []
    for value in values:
        if not isinstance(value, str) or not value.strip():
            continue
        normalized = normalized_gmail_api_id(value)
        if normalized is None:
            raise RuntimeError("gmail message id invalid")
        if normalized not in found:
            found.append(normalized)
    if not found:
        raise RuntimeError("gmail message id missing")
    if len(found) > 1:
        raise RuntimeError("gmail message id mismatch")
    return found[0]


def optional_gmail_api_id(value: object) -> str | None:
    if not isinstance(value, str) or not value.strip():
        return None
    return require_gmail_api_id(value)


def parsed_from_message(
    message: Message,
    fallback_message_id: str | None = None,
    gmail_api_id: str | None = None,
) -> dict[str, Any]:
    subject = decode_header_value(message.get("Subject"))
    from_addr = decode_header_value(message.get("From"))
    date = decode_header_value(message.get("Date"))
    message_id = (message.get("Message-ID") or message.get("Message-Id") or "").strip()
    if not message_id:
        fallback = fallback_message_id.strip() if isinstance(fallback_message_id, str) else ""
        message_id = fallback or synthetic_message_id(from_addr, date, subject)
    body, attachments = extract_body_and_attachments(message)
    email_hash = email_id_hash(message_id)
    api_id = optional_gmail_api_id(gmail_api_id)
    result: dict[str, Any] = {
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
            gmail_api_id=api_id,
        ),
    }
    if api_id:
        result["gmail_api_id"] = api_id
    return result


def b64url_decode(data: str) -> bytes:
    padded = data + "=" * ((4 - len(data) % 4) % 4)
    return base64.urlsafe_b64decode(padded.encode("ascii"))


def parsed_from_gmail_resource(
    resource: dict[str, Any],
    gmail_message_id: str | None = None,
) -> dict[str, Any]:
    raw = resource.get("raw")
    if not isinstance(raw, str) or not raw:
        log("Gmail-API Message ohne raw")
        raise RuntimeError("gmail raw missing")
    api_id = require_gmail_api_id(gmail_message_id, resource.get("id"))
    return parsed_from_message(
        email.message_from_bytes(b64url_decode(raw)),
        fallback_message_id=api_id,
        gmail_api_id=api_id,
    )


def oauth_credentials_from_env() -> dict[str, str] | None:
    creds: dict[str, str] = {}
    for key, env_name in OAUTH_ENV.items():
        value = os.environ.get(env_name, "").strip()
        if not value:
            return None
        creds[key] = value
    return creds


def require_mailbox(actual: str, expected: str) -> None:
    if actual.casefold() != expected.casefold():
        log("Gmail-Konto entspricht nicht der Feedback-Adresse")
        raise RuntimeError("gmail mailbox mismatch")


def read_json_response(request: urllib.request.Request, error_label: str) -> Any:
    try:
        with urllib.request.urlopen(request, timeout=HTTP_TIMEOUT_SEC) as response:
            raw = response.read()
            if not raw:
                return {}
            return json.loads(raw.decode("utf-8"))
    except urllib.error.HTTPError as error:
        log(f"{error_label} Status {error.code}")
        raise


def json_http_request(
    *,
    method: str,
    url: str,
    headers: dict[str, str],
    payload: dict[str, Any] | None = None,
    error_label: str,
) -> Any:
    data = None
    request_headers = dict(headers)
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        request_headers["Content-Type"] = "application/json"
    request = urllib.request.Request(url, data=data, headers=request_headers, method=method)
    return read_json_response(request, error_label)


def bearer_headers(token: str, extra: dict[str, str] | None = None) -> dict[str, str]:
    headers = {
        "Authorization": f"Bearer {token}",
        "User-Agent": USER_AGENT,
    }
    if extra:
        headers.update(extra)
    return headers


def github_request(token: str, method: str, url: str, payload: dict[str, Any] | None = None) -> Any:
    return json_http_request(
        method=method,
        url=url,
        headers=bearer_headers(
            token,
            {
                "Accept": "application/vnd.github+json",
                "X-GitHub-Api-Version": API_VERSION,
            },
        ),
        payload=payload,
        error_label="Issues-API",
    )


def gmail_request(
    access_token: str,
    method: str,
    url: str,
    payload: dict[str, Any] | None = None,
) -> Any:
    return json_http_request(
        method=method,
        url=url,
        headers=bearer_headers(access_token),
        payload=payload,
        error_label="Gmail-API",
    )


def gmail_get(access_token: str, url: str) -> Any:
    return gmail_request(access_token, "GET", url)


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
    decoded = read_json_response(request, "Gmail-OAuth Token-Refresh")
    token = decoded.get("access_token") if isinstance(decoded, dict) else None
    if not isinstance(token, str) or not token:
        log("Gmail-OAuth Token-Refresh ohne access_token")
        raise RuntimeError("oauth access_token missing")
    return token


def search_existing_issue(token: str, repo: str, email_hash: str) -> int | None:
    query = f"repo:{repo} is:issue in:body {EMAIL_ID_MARKER}:{email_hash}"
    url = f"{GITHUB_API}/search/issues?" + urllib.parse.urlencode({"q": query})
    decoded = github_request(token, "GET", url)
    items = decoded.get("items") if isinstance(decoded, dict) else None
    if not items:
        return None
    number = items[0].get("number")
    return int(number) if number is not None else None


def create_issue(token: str, repo: str, title: str, body: str) -> int:
    url = f"{GITHUB_API}/repos/{repo}/issues"
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
    profile = gmail_get(access_token, f"{GMAIL_API}/profile")
    actual = profile.get("emailAddress") if isinstance(profile, dict) else None
    if not isinstance(actual, str) or not actual:
        log("Gmail-Profil ohne Adresse")
        raise RuntimeError("gmail profile missing email")
    require_mailbox(actual, expected_address)

    listed = gmail_get(
        access_token,
        f"{GMAIL_API}/messages?"
        + urllib.parse.urlencode(
            {"q": UNREAD_FEEDBACK_QUERY, "maxResults": MAX_MAILS_PER_RUN}
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
        resource = gmail_get(
            access_token,
            message_url(mail_id) + "?" + urllib.parse.urlencode({"format": "raw"}),
        )
        if not isinstance(resource, dict):
            log("Gmail-API Message ohne Payload")
            raise RuntimeError("gmail message payload missing")
        parsed = parsed_from_gmail_resource(resource, gmail_message_id=mail_id)
        skipped = skip_ingest_reason(
            from_header=parsed["from"],
            label_ids=gmail_label_ids(resource),
        )
        if skipped is not None:
            log(f"Mail übersprungen ({skipped})")
            mark_read(access_token, mail_id)
            continue
        if should_skip_github_issue(parsed["body"]):
            log("Paste-Import-Dokument: kein GitHub-Issue (bleibt in Gmail)")
            mark_read(access_token, mail_id)
            continue
        existing = search_existing_issue(token, repo, parsed["email_hash"])
        if existing is not None:
            log(f"Duplikat übersprungen (Issue #{existing})")
        else:
            number = create_issue(token, repo, parsed["title"], parsed["issue_body"])
            log(f"Issue #{number} angelegt")
            created += 1
        mark_read(access_token, mail_id)
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
        if os.environ.get("GITHUB_ACTIONS") == "true":
            log("GITHUB_ACTIONS: OAuth-Secrets fehlen")
            return 1
        log("ingest übersprungen, Secret fehlt")
        return 0

    token = os.environ.get("GITHUB_TOKEN", "").strip()
    repo = os.environ.get("GITHUB_REPOSITORY", DEFAULT_REPO).strip()
    if not token:
        log("GITHUB_TOKEN fehlt")
        return 1
    if not repo:
        log("GITHUB_REPOSITORY fehlt")
        return 1

    created = ingest_unread(
        creds=creds,
        expected_address=DEFAULT_FEEDBACK_EMAIL,
        token=token,
        repo=repo,
    )
    log(f"Fertig, {created} Issue(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
