import json
import os
from valkey import Valkey
from dotenv import load_dotenv

from app.notifications.alert_engine import build_alert_payload
from app.notifications.router_client import http_post_json  # re-use your existing POST helper

load_dotenv()

def main():
    # Where your backend lives (ngrok or local)
    base_url = os.getenv("POLARIS_BASE_URL", "").rstrip("/")
    if not base_url:
        print("Set POLARIS_BASE_URL first (local or ngrok).")
        return

    dispatch_url = f"{base_url}/alert/dispatch"

    # Valkey connection
    host = os.getenv("VALKEY_HOST", "localhost")
    port = int(os.getenv("VALKEY_PORT", "6379"))
    channel = os.getenv("POLARIS_VALKEY_CHANNEL", "polaris:decisions")

    client = Valkey(host=host, port=port, decode_responses=True)
    pubsub = client.pubsub()
    pubsub.subscribe(channel)

    print(f"Listening on Valkey channel: {channel}")
    print(f"Dispatch endpoint: {dispatch_url}")

    last_signature = None

    for msg in pubsub.listen():
        if msg["type"] != "message":
            continue

        try:
            decision = json.loads(msg["data"])
        except Exception as e:
            print("Bad message JSON:", e)
            continue

        payload = build_alert_payload(decision)
        if not payload:
            print("No alert needed.")
            continue

        signature = (payload.get("severity"), payload.get("message"))
        if signature == last_signature:
            print("Duplicate alert ignored.")
            continue

        print("Dispatching:", payload)
        try:
            resp = http_post_json(dispatch_url, payload)
            print("Dispatch response:", resp)
            last_signature = signature
        except Exception as e:
            print("Dispatch failed:", e)

if __name__ == "__main__":
    main()
