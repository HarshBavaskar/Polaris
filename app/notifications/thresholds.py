# app/notifications/thresholds.py

"""
Severity-to-channel and severity-to-message definitions.
This module NEVER talks to APIs and NEVER modifies AI output.
"""

# Severity order (used for comparison & downgrade protection)
SEVERITY_ORDER = [
    "INFO",
    "ADVISORY",
    "WATCH",
    "WARNING",
    "ALERT",
    "EMERGENCY",
]

# Severity → Channel mapping
SEVERITY_CHANNEL_MAP = {
    "INFO": None,
    "ADVISORY": "APP_NOTIFICATION",
    "WATCH": "PUSH_NOTIFICATION",
    "WARNING": "PUSH_SMS",
    "ALERT": "SMS_SIREN",
    "EMERGENCY": "ALL_CHANNELS",
}

# Severity → Message templates
SEVERITY_MESSAGE_MAP = {
    "ADVISORY": "Weather advisory issued. Monitor conditions.",
    "WATCH": "Weather watch in effect. Stay alert.",
    "WARNING": (
        "⚠️ WARNING: {justification}. "
        "Expected impact in {final_eta} minutes."
    ),
    "ALERT": (
        "🚨 ALERT: {justification}. "
        "Move to safe areas immediately."
    ),
    "EMERGENCY": (
        "🆘 EMERGENCY: {justification}. "
        "Evacuate immediately."
    ),
}