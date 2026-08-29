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
from pathlib import Path
from typing import Any

_REPO_ROOT = Path(__file__).resolve().parent.parent
_GITHUB_REPOSITORY_SWIFT = (
    _REPO_ROOT / "Sources" / "ReisenDomain" / "Settings" / "GitHubRepository.swift"
)
_SECRET_REDACTOR_RULES_PATH = (
    _REPO_ROOT
    / "Sources"
    / "ReisenDomain"
    / "Resources"
    / "github-issue-secret-redactor.rules.json"
)


def swift_string_constant(source: str, name: str) -> str:
    match = re.search(rf'static let {re.escape(name)} = "([^"]+)"', source)
    if match is None:
        raise RuntimeError(f"GitHubRepository.{name} fehlt")
    return match.group(1)


def swift_int_constant(source: str, name: str) -> int:
    match = re.search(rf"static let {re.escape(name)} = ([0-9_]+)", source)
    if match is None:
        raise RuntimeError(f"GitHubRepository.{name} fehlt")
    return int(match.group(1).replace("_", ""))


def load_github_repository_ssot() -> dict[str, Any]:
    source = _GITHUB_REPOSITORY_SWIFT.read_text(encoding="utf-8")
    owner = swift_string_constant(source, "owner")
    name = swift_string_constant(source, "name")
    return {
        "feedbackEmail": swift_string_constant(source, "feedbackEmail"),
        "repo": f"{owner}/{name}",
        "restAPIVersion": swift_string_constant(source, "restAPIVersion"),
        "issueTitleMaxLength": swift_int_constant(source, "issueTitleMaxLength"),
        "issueTitleSummaryMaxLength": swift_int_constant(
            source, "issueTitleSummaryMaxLength"
        ),
        "issueBodyMaxLength": swift_int_constant(source, "issueBodyMaxLength"),
        "issueMarkdownH2Prefix": swift_string_constant(source, "issueMarkdownH2Prefix"),
        "issueBodyTruncationNoticeTemplate": swift_string_constant(
            source, "issueBodyTruncationNoticeTemplate"
        ),
        "issueAttachmentPolicyCellTemplate": swift_string_constant(
            source, "issueAttachmentPolicyCellTemplate"
        ),
    }


_GITHUB_REPOSITORY = load_github_repository_ssot()
DEFAULT_FEEDBACK_EMAIL = str(_GITHUB_REPOSITORY["feedbackEmail"])
DEFAULT_REPO = str(_GITHUB_REPOSITORY["repo"])
MAX_MAILS_PER_RUN = 20
TITLE_PREFIX = "[Feedback]"
MAX_SUBJECT = int(_GITHUB_REPOSITORY["issueTitleSummaryMaxLength"])
MAX_ISSUE_TITLE = int(_GITHUB_REPOSITORY["issueTitleMaxLength"])
MAX_ISSUE_BODY = int(_GITHUB_REPOSITORY["issueBodyMaxLength"])
MARKDOWN_H2_PREFIX = str(_GITHUB_REPOSITORY["issueMarkdownH2Prefix"])
MARKDOWN_SECTION_HEADING = "\n" + MARKDOWN_H2_PREFIX
MAX_TEXT_ATTACHMENT = 20_000
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
API_VERSION = str(_GITHUB_REPOSITORY["restAPIVersion"])
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


def icu_template_to_python(template: str) -> str:
    return re.sub(r"\$(\d+)", r"\\g<\1>", template)


def load_secret_redactor_spec() -> dict[str, Any]:
    with _SECRET_REDACTOR_RULES_PATH.open(encoding="utf-8") as handle:
        spec = json.load(handle)
    if not isinstance(spec, dict):
        raise RuntimeError("secret redactor rules must be an object")
    min_length = spec.get("markdownCodeFenceMinLength")
    rules = spec.get("rules")
    if not isinstance(min_length, int) or min_length < 3:
        raise RuntimeError("markdownCodeFenceMinLength ungültig")
    if not isinstance(rules, list) or not rules:
        raise RuntimeError("secret redactor rules fehlen")
    for rule in rules:
        if not isinstance(rule, dict):
            raise RuntimeError("secret redactor rule must be an object")
        if not isinstance(rule.get("pattern"), str) or not isinstance(rule.get("template"), str):
            raise RuntimeError("secret redactor rule missing pattern/template")
    return spec


_SECRET_REDACTOR_SPEC = load_secret_redactor_spec()
MARKDOWN_FENCE_MIN = int(_SECRET_REDACTOR_SPEC["markdownCodeFenceMinLength"])
_REDACT_RULES: tuple[tuple[str, str], ...] = tuple(
    (str(rule["pattern"]), icu_template_to_python(str(rule["template"])))
    for rule in _SECRET_REDACTOR_SPEC["rules"]
)


def redact_secrets(text: str) -> str:
    redacted = text
    for pattern, replacement in _REDACT_RULES:
        redacted = re.sub(pattern, replacement, redacted)
    return redacted


def markdown_h2(title: str) -> str:
    return MARKDOWN_H2_PREFIX + title


def markdown_fence(text: str) -> str:
    longest = max((len(match.group(0)) for match in re.finditer(r"`+", text)), default=0)
    fence = "`" * max(MARKDOWN_FENCE_MIN, longest + 1)
    return f"{fence}\n{text}\n{fence}"


def fenced_heading(heading: str, text: str) -> str:
    return f"{markdown_h2(heading)}\n{markdown_fence(text)}"


TEXT_ATTACHMENT_TYPES = {
    "text/plain",
    "text/csv",
    "text/markdown",
    "text/x-log",
    "text/xml",
    "application/json",
    "application/xml",
}
TEXT_ATTACHMENT_SUFFIXES = (
    ".txt",
    ".log",
    ".crash",
    ".json",
    ".md",
    ".xml",
    ".csv",
    ".ips",
)
NON_TEXT_TYPE_PREFIXES = ("image/", "audio/", "video/")
NON_TEXT_TYPES = {
    "application/octet-stream",
    "application/pdf",
    "application/zip",
    "application/gzip",
    "application/x-gzip",
    "application/x-tar",
    "application/x-7z-compressed",
    "application/vnd.rar",
}


def is_non_text_content_type(content_type: str) -> bool:
    lowered = content_type.lower()
    return lowered.startswith(NON_TEXT_TYPE_PREFIXES) or lowered in NON_TEXT_TYPES


def is_text_attachment(filename: str, content_type: str) -> bool:
    if is_non_text_content_type(content_type):
        return False
    lowered_type = content_type.lower()
    if lowered_type in TEXT_ATTACHMENT_TYPES:
        return True
    lowered_name = filename.casefold()
    return any(lowered_name.endswith(suffix) for suffix in TEXT_ATTACHMENT_SUFFIXES)


def extract_body_and_attachments(
    message: Message,
) -> tuple[str, list[str], list[tuple[str, str]]]:
    attachments: list[str] = []
    inlined: list[tuple[str, str]] = []
    plain_parts: list[str] = []
    html_parts: list[str] = []

    if message.is_multipart():
        for part in message.walk():
            disposition = (part.get_content_disposition() or "").lower()
            filename = decode_header_value(part.get_filename())
            if disposition == "attachment" or filename:
                name = filename or "unnamed"
                attachments.append(name)
                content_type = part.get_content_type()
                if is_text_attachment(name, content_type):
                    text = part_payload_text(part).strip()
                    if text:
                        inlined.append((name, text))
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
    return body.strip(), attachments, inlined


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


def redacted_issue_field(value: str) -> str:
    return redact_secrets(sanitized_issue_field(value))


def filled_email(template: object) -> str:
    return str(template).replace("{email}", DEFAULT_FEEDBACK_EMAIL)


ISSUE_BODY_TRUNCATION_NOTICE = filled_email(
    _GITHUB_REPOSITORY["issueBodyTruncationNoticeTemplate"]
)
ISSUE_ATTACHMENT_POLICY_CELL = filled_email(
    _GITHUB_REPOSITORY["issueAttachmentPolicyCellTemplate"]
)
ISSUE_ATTACHMENT_POLICY_PARAGRAPH = filled_email(
    "Die GitHub-Issues-API unterstützt keine Dateianhänge. "
    "Textanhänge stehen als Text in diesem Issue. "
    "Binäre Dateien bleiben in der Mailbox ({email}) und werden nicht auf GitHub hochgeladen."
)


def issue_subject_summary(subject: str) -> str:
    collapsed = re.sub(r"\s+", " ", sanitized_issue_field(subject)).strip() or EMPTY_SUBJECT
    return redacted_issue_field(collapsed)


def issue_title(subject: str) -> str:
    title = f"{TITLE_PREFIX} {issue_subject_summary(subject)[:MAX_SUBJECT]}"
    return title[:MAX_ISSUE_TITLE]


def issue_marker(name: str, value: str) -> str:
    return f"{name}: `{value}`\n<!-- {name}: {value} -->\n"


def issue_table_cell(value: str) -> str:
    return value or EMPTY_CELL


def issue_attachment_cell(attachments: list[str]) -> str:
    names = [name for name in (redacted_issue_field(raw) for raw in attachments) if name]
    return ", ".join(names) if names else EMPTY_CELL


def clamp_issue_body(text: str, *, markers: str) -> str:
    if len(text) + len(markers) <= MAX_ISSUE_BODY:
        return text + markers
    notice = "\n\n" + ISSUE_BODY_TRUNCATION_NOTICE
    keep = max(0, MAX_ISSUE_BODY - len(notice) - len(markers))
    return trim_to_heading_boundary(text, keep) + notice + markers


def trim_to_heading_boundary(text: str, max_characters: int) -> str:
    if len(text) <= max_characters:
        return text
    prefix = text[:max_characters]
    chunks = text.split(MARKDOWN_SECTION_HEADING)
    if len(chunks) <= 1:
        return prefix
    sections = [chunks[0]] + [MARKDOWN_SECTION_HEADING + chunk for chunk in chunks[1:]]
    acc = ""
    for section in sections:
        if len(acc) + len(section) > max_characters:
            break
        acc += section
    return acc if acc else prefix


def issue_from_cell(from_header: str) -> str:
    return "[redacted]" if sanitized_issue_field(from_header) else EMPTY_CELL


def inlined_attachment_sections(inlined: list[tuple[str, str]]) -> str:
    sections: list[str] = []
    for name, text in inlined:
        heading = redacted_issue_field(name) or "unnamed"
        clipped = redacted_issue_field(text)
        if not clipped:
            continue
        if len(clipped) > MAX_TEXT_ATTACHMENT:
            clipped = clipped[:MAX_TEXT_ATTACHMENT] + "\n… (Anhang gekürzt)"
        sections.append(fenced_heading(f"Anhang: {heading}", clipped))
    if not sections:
        return ""
    return "\n\n" + "\n\n".join(sections) + "\n"


def issue_body(
    *,
    from_addr: str,
    date: str,
    subject: str,
    body: str,
    attachments: list[str],
    email_hash: str,
    gmail_api_id: str | None = None,
    inlined_attachments: list[tuple[str, str]] | None = None,
) -> str:
    from_addr = issue_from_cell(from_addr)
    date = redacted_issue_field(date)
    summary = issue_subject_summary(subject)
    text = redacted_issue_field(body) or EMPTY_MAIL_TEXT
    inlined = inlined_attachments or []
    markers = issue_marker(EMAIL_ID_MARKER, email_hash)
    if gmail_api_id:
        markers += issue_marker(GMAIL_ID_MARKER, gmail_api_id)
    return clamp_issue_body(
        f"{markdown_h2('Zusammenfassung')}\n"
        f"{summary}\n\n"
        f"{markdown_h2('Diagnose')}\n"
        "| Feld | Wert |\n"
        "| --- | --- |\n"
        "| Art | feedback |\n"
        "| Meldeweg | E-Mail |\n"
        f"| Von | {issue_table_cell(from_addr)} |\n"
        f"| Datum | {issue_table_cell(date)} |\n"
        f"| Anhänge | {issue_attachment_cell(attachments)} |\n"
        f"| Dateianhänge | {ISSUE_ATTACHMENT_POLICY_CELL} |\n\n"
        f"{ISSUE_ATTACHMENT_POLICY_PARAGRAPH}\n\n"
        f"{fenced_heading('Fehler', text)}\n"
        f"{inlined_attachment_sections(inlined)}\n",
        markers=markers,
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
    body, attachments, inlined = extract_body_and_attachments(message)
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
            inlined_attachments=inlined,
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
