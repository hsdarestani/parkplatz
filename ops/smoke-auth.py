#!/usr/bin/env python3
"""Exercise the production authentication lifecycle against a running API.

The probe creates a disposable account, verifies the authenticated profile, and
removes the account again. It exits non-zero and prints the exact HTTP response
when any stage fails, so deployment logs expose registration regressions instead
of reporting a misleading healthy API.
"""

from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class Response:
    status: int
    body: bytes

    def json(self) -> Any:
        return json.loads(self.body.decode("utf-8")) if self.body else None


def request(
    method: str,
    url: str,
    *,
    payload: dict[str, Any] | None = None,
    token: str | None = None,
) -> Response:
    headers = {"Accept": "application/json"}
    data = None
    if payload is not None:
        headers["Content-Type"] = "application/json"
        data = json.dumps(payload).encode("utf-8")
    if token:
        headers["Authorization"] = f"Bearer {token}"

    try:
        with urllib.request.urlopen(
            urllib.request.Request(
                url,
                data=data,
                headers=headers,
                method=method,
            ),
            timeout=20,
        ) as response:
            return Response(response.status, response.read())
    except urllib.error.HTTPError as error:
        return Response(error.code, error.read())


def require(response: Response, expected: int, stage: str) -> Any:
    if response.status != expected:
        body = response.body.decode("utf-8", errors="replace")
        raise RuntimeError(
            f"{stage} failed: expected HTTP {expected}, got {response.status}: {body}"
        )
    return response.json()


def main() -> int:
    base_url = os.environ.get("FREIRAUM_API_BASE_URL", "http://127.0.0.1:8000/api").rstrip("/")
    nonce = f"{int(time.time())}-{os.getpid()}"
    email = f"auth-probe-{nonce}@example.com"
    password = "FREIRAUM-Probe-2026!"

    registered = require(
        request(
            "POST",
            f"{base_url}/auth/register",
            payload={
                "display_name": "FREIRAUM Auth Probe",
                "email": email,
                "password": password,
            },
        ),
        201,
        "registration",
    )
    if not isinstance(registered, dict):
        raise RuntimeError("registration returned a non-object response")
    access_token = registered.get("access_token")
    if not isinstance(access_token, str) or not access_token:
        raise RuntimeError("registration response did not include access_token")

    profile = require(
        request("GET", f"{base_url}/auth/me", token=access_token),
        200,
        "authenticated profile",
    )
    if not isinstance(profile, dict) or profile.get("email") != email:
        raise RuntimeError(f"authenticated profile mismatch: {profile!r}")

    require(
        request(
            "POST",
            f"{base_url}/account/delete",
            payload={"password": password, "confirmation": "DELETE"},
            token=access_token,
        ),
        204,
        "account cleanup",
    )

    print("FREIRAUM registration, authenticated profile, and account cleanup passed.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"AUTH PROBE ERROR: {error}", file=sys.stderr)
        raise
