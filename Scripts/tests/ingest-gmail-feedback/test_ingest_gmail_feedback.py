#!/usr/bin/env python3
from __future__ import annotations

import base64
import email
import importlib.util
import os
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "Scripts" / "ingest-gmail-feedback.py"
FIXTURES = Path(__file__).resolve().parent / "fixtures"


def load_ingest():
    spec = importlib.util.spec_from_file_location("ingest_gmail_feedback", SCRIPT)
    if spec is None or spec.loader is None:
        raise RuntimeError("ingest module not loadable")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


ingest = load_ingest()


def oauth_test_env() -> dict[str, str]:
    return {
        ingest.OAUTH_ENV["client_id"]: "id",
        ingest.OAUTH_ENV["client_secret"]: "secret",
        ingest.OAUTH_ENV["refresh_token"]: "refresh",
    }


def gmail_raw_resource(name: str, resource_id: str) -> dict[str, str]:
    raw = (FIXTURES / name).read_bytes()
    encoded = base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")
    return {"raw": encoded, "id": resource_id}


class IngestGmailFeedbackTests(unittest.TestCase):
    def parse_fixture(self, name: str) -> dict:
        raw = (FIXTURES / name).read_bytes()
        return ingest.parsed_from_message(email.message_from_bytes(raw))

    def test_default_email_matches_public_ssot(self) -> None:
        self.assertEqual(ingest.DEFAULT_FEEDBACK_EMAIL, "reisenapp100@gmail.com")
        self.assertIn("reisenapp100@gmail.com", SCRIPT.read_text(encoding="utf-8"))

    def test_plain_mail_becomes_feedback_issue(self) -> None:
        parsed = self.parse_fixture("plain.eml")
        self.assertEqual(parsed["title"], f"{ingest.TITLE_PREFIX} App stuerzt beim Sync ab")
        self.assertIn("kind/feedback", ingest.LABELS)
        self.assertIn("source/email", ingest.LABELS)
        self.assertIn(f"{ingest.EMAIL_ID_MARKER}:", parsed["issue_body"])
        self.assertIn("user@example.com", parsed["issue_body"])
        self.assertIn("die App stuerzt beim Sync ab", parsed["issue_body"])
        self.assertEqual(
            parsed["email_hash"],
            ingest.email_id_hash("<plain-fixture@mail.example>"),
        )

    def test_html_without_message_id_is_synthetic_and_text(self) -> None:
        parsed = self.parse_fixture("html.eml")
        self.assertTrue(parsed["message_id"].startswith("synthetic-"))
        self.assertIn("Erste Zeile", parsed["body"])
        self.assertNotIn("<p>", parsed["body"])
        self.assertEqual(parsed["title"], f"{ingest.TITLE_PREFIX} HTML only")

    def test_gmail_id_is_used_when_header_message_id_is_missing(self) -> None:
        first = ingest.parsed_from_gmail_resource(
            gmail_raw_resource("html.eml", "gmail-id-a"),
            gmail_message_id="gmail-id-a",
        )
        second = ingest.parsed_from_gmail_resource(
            gmail_raw_resource("html.eml", "gmail-id-b"),
            gmail_message_id="gmail-id-b",
        )
        self.assertEqual(first["message_id"], "gmail-id-a")
        self.assertNotEqual(first["email_hash"], second["email_hash"])
        self.assertEqual(first["email_hash"], ingest.email_id_hash("gmail-id-a"))

    def test_duplicate_hash_is_stable(self) -> None:
        first = self.parse_fixture("plain.eml")
        second = self.parse_fixture("plain.eml")
        self.assertEqual(first["email_hash"], second["email_hash"])

    def test_gmail_raw_resource_uses_same_parser(self) -> None:
        parsed = ingest.parsed_from_gmail_resource(
            gmail_raw_resource("plain.eml", "18plainGmailId01")
        )
        self.assertEqual(parsed["title"], f"{ingest.TITLE_PREFIX} App stuerzt beim Sync ab")
        self.assertEqual(
            parsed["email_hash"],
            ingest.email_id_hash("<plain-fixture@mail.example>"),
        )
        self.assertEqual(parsed["gmail_api_id"], "18plainGmailId01")

    def test_gmail_resource_rejects_invalid_id(self) -> None:
        with self.assertRaises(RuntimeError):
            ingest.parsed_from_gmail_resource(
                gmail_raw_resource("plain.eml", "not a valid id")
            )

    def test_gmail_resource_rejects_list_and_resource_id_mismatch(self) -> None:
        with self.assertRaises(RuntimeError):
            ingest.parsed_from_gmail_resource(
                gmail_raw_resource("plain.eml", "18resourceId01"),
                gmail_message_id="18listId01",
            )

    def test_gmail_raw_resource_rejects_missing_payload(self) -> None:
        with self.assertRaises(RuntimeError):
            ingest.parsed_from_gmail_resource({})

    def test_oauth_credentials_missing_when_any_secret_absent(self) -> None:
        with mock.patch.dict(os.environ, {}, clear=True):
            self.assertIsNone(ingest.oauth_credentials_from_env())
        partial = oauth_test_env()
        del partial[ingest.OAUTH_ENV["refresh_token"]]
        with mock.patch.dict(os.environ, partial, clear=True):
            self.assertIsNone(ingest.oauth_credentials_from_env())

    def test_oauth_credentials_complete(self) -> None:
        env = oauth_test_env()
        with mock.patch.dict(os.environ, env, clear=True):
            creds = ingest.oauth_credentials_from_env()
        self.assertEqual(
            creds,
            {
                "client_id": "id",
                "client_secret": "secret",
                "refresh_token": "refresh",
            },
        )

    def test_main_skips_without_oauth_secrets(self) -> None:
        with mock.patch.dict(os.environ, {}, clear=True):
            self.assertEqual(ingest.main([]), 0)

    def test_main_fails_in_github_actions_without_oauth_secrets(self) -> None:
        with mock.patch.dict(os.environ, {"GITHUB_ACTIONS": "true"}, clear=True):
            self.assertEqual(ingest.main([]), 1)

    def test_main_requires_github_token_when_oauth_present(self) -> None:
        env = oauth_test_env()
        with mock.patch.dict(os.environ, env, clear=True):
            self.assertEqual(ingest.main([]), 1)

    def test_mailbox_mismatch_is_error(self) -> None:
        with self.assertRaises(RuntimeError):
            ingest.require_mailbox("other@gmail.com", ingest.DEFAULT_FEEDBACK_EMAIL)

    def test_mailbox_match_is_case_insensitive(self) -> None:
        ingest.require_mailbox("ReisenApp100@gmail.com", ingest.DEFAULT_FEEDBACK_EMAIL)

    def test_script_does_not_use_imap_or_app_password(self) -> None:
        source = SCRIPT.read_text(encoding="utf-8")
        self.assertNotIn("imaplib", source)
        self.assertNotIn("REISEN_FEEDBACK_GMAIL_APP_PASSWORD", source)
        self.assertNotIn("REISEN_FEEDBACK_GMAIL_ADDRESS", source)
        self.assertIn(ingest.OAUTH_ENV["refresh_token"], source)
        self.assertIn(ingest.GMAIL_ID_MARKER, source)

    def test_gmail_api_id_is_embedded_for_the_bot(self) -> None:
        parsed = ingest.parsed_from_gmail_resource(
            gmail_raw_resource("plain.eml", "18abcGmailId01"),
            gmail_message_id="18abcGmailId01",
        )
        self.assertEqual(parsed["gmail_api_id"], "18abcGmailId01")
        self.assertIn(f"{ingest.GMAIL_ID_MARKER}: `18abcGmailId01`", parsed["issue_body"])
        self.assertIn(f"<!-- {ingest.GMAIL_ID_MARKER}: 18abcGmailId01 -->", parsed["issue_body"])

    def test_plain_eml_without_gmail_api_id_has_no_bot_marker(self) -> None:
        parsed = self.parse_fixture("plain.eml")
        self.assertNotIn(ingest.GMAIL_ID_MARKER, parsed["issue_body"])
        self.assertNotIn("gmail_api_id", parsed)

    def test_html_comments_stripped_from_untrusted_issue_fields(self) -> None:
        injected = f"<!-- {ingest.GMAIL_ID_MARKER}: 18injectId01 -->"
        body = ingest.issue_body(
            from_addr=f"Eve {injected} <eve@example.com>",
            date=f"Sat, 29 Aug 2026 {injected}",
            subject=f"Crash {injected}",
            body=f"dump\n{injected}\nstack",
            attachments=[f"crash.zip{injected}"],
            email_hash="abc",
            gmail_api_id="18realGmailId01",
        )
        self.assertNotIn("18injectId01", body)
        self.assertIn(f"<!-- {ingest.GMAIL_ID_MARKER}: 18realGmailId01 -->", body)
        self.assertEqual(body.count(f"<!-- {ingest.GMAIL_ID_MARKER}:"), 1)
        self.assertNotIn("18injectId01", ingest.issue_title(f"Crash {injected}"))


if __name__ == "__main__":
    unittest.main()
