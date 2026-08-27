#!/usr/bin/env python3
"""Einmalig Refresh-Token für den Gmail-Feedback-Ingress holen.

Login im Browser als reisenapp100@gmail.com. Secrets nie in Dateien schreiben.
"""
from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
import webbrowser
from http.server import BaseHTTPRequestHandler, HTTPServer
from typing import Any

USER_AGENT = "reisen-gmail-feedback-oauth"
TOKEN_URL = "https://oauth2.googleapis.com/token"
AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
SCOPE = "https://www.googleapis.com/auth/gmail.modify"
DEFAULT_FEEDBACK_EMAIL = "reisenapp100@gmail.com"
LISTEN_HOST = "127.0.0.1"
LISTEN_PORT = 8765


def log(message: str) -> None:
    print(message, file=sys.stderr)


class OAuthHandler(BaseHTTPRequestHandler):
    code: str | None = None
    error: str | None = None

    def do_GET(self) -> None:
        parsed = urllib.parse.urlparse(self.path)
        query = urllib.parse.parse_qs(parsed.query)
        if query.get("error"):
            OAuthHandler.error = query["error"][0]
        elif query.get("code"):
            OAuthHandler.code = query["code"][0]
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(
            "<p>Autorisierung abgeschlossen. Dieses Fenster kann geschlossen werden.</p>".encode(
                "utf-8"
            )
        )

    def log_message(self, format: str, *args: Any) -> None:
        return


def redirect_uri() -> str:
    return f"http://{LISTEN_HOST}:{LISTEN_PORT}/"


def exchange_code(client_id: str, client_secret: str, code: str) -> str:
    body = urllib.parse.urlencode(
        {
            "client_id": client_id,
            "client_secret": client_secret,
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": redirect_uri(),
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
        log(f"Gmail-OAuth Code-Tausch Status {error.code}")
        raise
    token = decoded.get("refresh_token") if isinstance(decoded, dict) else None
    if not isinstance(token, str) or not token:
        log("Kein Refresh-Token. Consent mit access_type=offline und prompt=consent wiederholen.")
        raise RuntimeError("oauth refresh_token missing")
    return token


def main() -> int:
    client_id = os.environ.get("REISEN_GMAIL_OAUTH_CLIENT_ID", "").strip()
    client_secret = os.environ.get("REISEN_GMAIL_OAUTH_CLIENT_SECRET", "").strip()
    if not client_id or not client_secret:
        log("REISEN_GMAIL_OAUTH_CLIENT_ID und REISEN_GMAIL_OAUTH_CLIENT_SECRET setzen")
        return 1

    params = {
        "client_id": client_id,
        "redirect_uri": redirect_uri(),
        "response_type": "code",
        "scope": SCOPE,
        "access_type": "offline",
        "prompt": "consent",
        "login_hint": DEFAULT_FEEDBACK_EMAIL,
    }
    url = AUTH_URL + "?" + urllib.parse.urlencode(params)
    log("Im Browser als reisenapp100@gmail.com anmelden.")
    log(url)
    webbrowser.open(url)

    server = HTTPServer((LISTEN_HOST, LISTEN_PORT), OAuthHandler)
    try:
        while OAuthHandler.code is None and OAuthHandler.error is None:
            server.handle_request()
    finally:
        server.server_close()

    if OAuthHandler.error is not None:
        log("OAuth abgelehnt")
        return 1
    if OAuthHandler.code is None:
        log("OAuth ohne Code")
        return 1

    refresh_token = exchange_code(client_id, client_secret, OAuthHandler.code)
    print(refresh_token)
    log("Refresh-Token steht in stdout. Als GitHub-Secret REISEN_GMAIL_OAUTH_REFRESH_TOKEN speichern.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
