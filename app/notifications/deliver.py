from typing import Dict

from app.notifications.fcm_push import send_push_fcm


SUPPORTED_CHANNELS = {
    "APP_NOTIFICATION",
    "PUSH_NOTIFICATION",
    "PUSH_SMS",
    "SMS_SIREN",
    "ALL_CHANNELS",
}


def deliver(payload: Dict) -> Dict:
    """
    Delivery router.
    All supported channels are delivered using FCM only.
    """
    channel = (payload.get("channel") or "").upper()
    if channel not in SUPPORTED_CHANNELS:
        return {
            "ok": False,
            "channel": channel,
            "error": f"No delivery route defined for channel '{channel}'",
        }

    fcm_result = send_push_fcm(payload)
    return {
        "ok": bool(fcm_result.get("ok")),
        "channel": channel,
        "provider": "fcm",
        "results": {"fcm": fcm_result},
    }
