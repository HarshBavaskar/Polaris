import os
import requests
from typing import Dict

ONESIGNAL_API_URL = "https://api.onesignal.com/notifications"

def send_push_onesignal(payload: Dict) -> Dict:
    """
    Sends a push notification using OneSignal REST API.
    Dev target: 'Test Users' segment.
    """
    app_id = os.getenv("ONESIGNAL_APP_ID")
    api_key = os.getenv("ONESIGNAL_REST_API_KEY")

    if not app_id or not api_key:
        return {"ok": False, "error": "Missing ONESIGNAL_APP_ID / ONESIGNAL_REST_API_KEY in .env"}

    title = payload.get("title", "Polaris Alert")
    message = payload.get("message", "Alert triggered")

    body = {
        "app_id": app_id,
        "target_channel": "push",
        "headings": {"en": title},
        "contents": {"en": message},
        "included_segments": ["Test Users"]
    }

    headers = {
        "Content-Type": "application/json; charset=utf-8",
        "Authorization": f"Key {api_key}"
    }

    try:
        r = requests.post(ONESIGNAL_API_URL, json=body, headers=headers, timeout=15)
        if 200 <= r.status_code < 300:
            return {"ok": True, "provider": "onesignal", "status_code": r.status_code, "resp": r.json()}
        return {"ok": False, "provider": "onesignal", "status_code": r.status_code, "resp": r.text}
    except Exception as e:
        return {"ok": False, "error": str(e)}
