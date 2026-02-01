# app/notifications/router_client.py

"""
Notification Router Client (Phase 1)

Connects to partner server:
- GET /decision/latest
- Builds alert payload
- POST /alert/dispatch

Runs only when explicitly executed.
"""

import os
import time
import json
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError

from app.notifications.alert_engine import build_alert_payload


def http_get_json(url: str, timeout: int = 5) -> dict:
    req = Request(url, method="GET")
    with urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))


def http_post_json(url: str, payload: dict, timeout: int = 5) -> dict:
    body = json.dumps(payload).encode("utf-8")
    req = Request(url, data=body, method="POST")
    req.add_header("Content-Type", "application/json")
    with urlopen(req, timeout=timeout) as resp:
        data = resp.read().decode("utf-8")
        return json.loads(data) if data else {"ok": True}


def main():
    base_url = os.getenv("POLARIS_BASE_URL")
    if not base_url:
        print(
            "POLARIS_BASE_URL not set. "
            "Example: export POLARIS_BASE_URL='http://localhost:8000'"
        )
        return

    base_url = base_url.rstrip("/")
    decision_url = f"{base_url}/decision/latest"
    dispatch_url = f"{base_url}/alert/dispatch"

    print(f"Polling: {decision_url}")
    last_signature = None

    while True:
        try:
            decision = http_get_json(decision_url)
        except (URLError, HTTPError) as e:
            print("GET failed:", e)
            time.sleep(5)
            continue

        payload = build_alert_payload(decision)

        if payload:
            signature = (payload["severity"], payload["message"])
            if signature != last_signature:
                print("Dispatching:", payload)
                try:
                    resp = http_post_json(dispatch_url, payload)
                    print("Dispatch response:", resp)
                    last_signature = signature
                except (URLError, HTTPError) as e:
                    print("POST failed:", e)
            else:
                print("Duplicate alert ignored.")
        else:
            print("No alert needed.")

        time.sleep(5)


if __name__ == "__main__":
    main()