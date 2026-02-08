from typing import Dict
from app.notifications.onesignal_push import send_push_onesignal

def deliver(payload: Dict) -> Dict:
    """
    Delivery router.
    Push -> OneSignal
    SMS -> simulated for now
    """
    channel = payload.get("channel")

    if channel in ("APP_NOTIFICATION", "PUSH_NOTIFICATION", "ALL_CHANNELS"):
        return send_push_onesignal(payload)

    if channel in ("PUSH_SMS", "SMS_SIREN"):
        return {"ok": True, "provider": "simulated", "note": "SMS not wired yet in this version"}

    return {"ok": True, "provider": "simulated", "note": f"No sender wired for {channel} yet"}