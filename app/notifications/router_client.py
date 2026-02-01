# app/notifications/router_client.py

"""
Notification Router Client (Phase 1)

This will later connect to your partner's server:
- GET /decision/latest
- Decide channel/message using build_alert_payload()
- POST /alert/dispatch

Right now: safe to keep in repo; won't run unless you execute it.
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
        data = resp.read().decode("utf-8")
        return json.loads(data)


def http_post_json(url: str, payload: dict, timeout: int = 5) -> dict:
    body = json.dumps(payload).encode("utf-8")
    req = Request(url, data=body, method="POST")
    req.add_header("Content-Type", "application/json")
    with urlopen(req, timeout=timeout) as resp:
        data = resp.read().decode("utf-8")
        return json.loads(data) if data else {"ok": True}


def main():
    base_url = os.getenv("POLARIS_BASE_URL", "https://barometric-iesha-nonprovidentially.ngrok-free.dev/").rstrip("/")
    if not base_url:
        print("POLARIS_BASE_URL is not set. Example: export POLARIS_BASE_URL='http://192.168.1.10:8000'")
        return

    decision_url = f"{base_url}/decision/latest"
    dispatch_url = f"{base_url}/alert/dispatch"

    print(f"Polling: {decision_url}")
    last_signature = None  # prevents repeating the same alert forever

    while True:
        try:
            decision = http_get_json(decision_url)
        except (URLError, HTTPError) as e:
            print("GET failed:", e)
            time.sleep(5)
            continue

        # Depending on partner response shape:
        # If response is {"final_decision": {...}}, unwrap it.
        final_decision = decision.get("final_decision", decision)

        payload = build_alert_payload(final_decision)
        if payload:
            signature = (payload.get("severity"), payload.get("message"))
            if signature != last_signature:
                print("Dispatching:", payload)
                try:
                    resp = http_post_json(dispatch_url, payload)
                    print("Dispatch response:", resp)
                    last_signature = signature
                except (URLError, HTTPError) as e:
                    print("POST failed:", e)
            else:
                print("No new alert (duplicate).")

        else:
            print("No alert needed.")

        time.sleep(5)


if __name__ == "__main__":
    main()