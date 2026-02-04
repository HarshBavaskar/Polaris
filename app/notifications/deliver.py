import os
from typing import Dict

def send_sms_twilio(payload: Dict) -> Dict:
    """
    Real SMS sender using Twilio.
    Returns a status dict you can store in DB.
    """
    try:
        from twilio.rest import Client
    except ImportError:
        return {"ok": False, "error": "twilio not installed. pip install twilio"}

    account_sid = os.getenv("TWILIO_ACCOUNT_SID")
    auth_token = os.getenv("TWILIO_AUTH_TOKEN")
    from_number = os.getenv("TWILIO_FROM_NUMBER")
    to_number = os.getenv("ALERT_TO_NUMBER")  # your phone for testing

    if not all([account_sid, auth_token, from_number, to_number]):
        return {
            "ok": False,
            "error": "Missing Twilio env vars. Set TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_FROM_NUMBER, ALERT_TO_NUMBER"
        }

    client = Client(account_sid, auth_token)
    msg = client.messages.create(
        body=payload["message"],
        from_=from_number,
        to=to_number
    )

    return {"ok": True, "provider": "twilio", "sid": msg.sid}


def deliver(payload: Dict) -> Dict:
    """
    Routes delivery based on channel.
    For now: only SMS channels send real SMS.
    """
    channel = payload.get("channel")

    if channel in ("PUSH_SMS", "SMS_SIREN", "ALL_CHANNELS"):
        return send_sms_twilio(payload)

    # For now, other channels just simulate
    return {"ok": True, "provider": "simulated", "note": f"No real sender wired for {channel} yet"}