from __future__ import annotations

import os
from pathlib import Path

import requests
from dotenv import load_dotenv


REPO_ROOT = Path(__file__).resolve().parents[2]
load_dotenv(REPO_ROOT / ".env")


_TOKEN_CACHE: dict[tuple[str, str], str] = {}


def _resolve_credentials(preferred_role: str) -> tuple[str | None, str | None]:
    if preferred_role == "ingest":
        username = (os.getenv("POLARIS_INGEST_USERNAME") or "").strip()
        password = (os.getenv("POLARIS_INGEST_PASSWORD") or "").strip()
        if username and password:
            return username, password

    username = (os.getenv("POLARIS_AUTH_USERNAME") or "").strip()
    password = (os.getenv("POLARIS_AUTH_PASSWORD") or "").strip()
    return (username or None, password or None)


def build_auth_headers(base_url: str, *, preferred_role: str) -> dict[str, str]:
    username, password = _resolve_credentials(preferred_role)
    if not username or not password:
        return {}

    cache_key = (base_url.rstrip("/"), preferred_role)
    token = _TOKEN_CACHE.get(cache_key)
    if token:
        return {"Authorization": f"Bearer {token}"}

    try:
        response = requests.post(
            f"{cache_key[0]}/auth/token",
            json={"username": username, "password": password},
            timeout=5,
        )
        response.raise_for_status()
        payload = response.json()
    except (requests.RequestException, ValueError):
        return {}

    token = str(payload.get("access_token") or "").strip()
    if not token:
        return {}

    _TOKEN_CACHE[cache_key] = token
    return {"Authorization": f"Bearer {token}"}
