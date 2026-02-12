# app/notifications/alert_engine.py

"""
Alert decision engine.
Consumes final_decision JSON from /decision/latest
and prepares payload for /alert/dispatch.
"""

from app.notifications.thresholds import (
    SEVERITY_CHANNEL_MAP,
    SEVERITY_MESSAGE_MAP,
)


def build_alert_payload(final_decision: dict):
    """
    Input: final_decision (dict) from GET /decision/latest
    Output: dict ready for POST /alert/dispatch OR None
    """

    if not final_decision:
        return None

    # Handle wrapped responses safely
    if "final_decision" in final_decision:
        final_decision = final_decision["final_decision"]

    severity = final_decision.get("final_alert_severity")

    # No severity or INFO → no alert
    if not severity or severity.upper() == "INFO":
        return None

    severity = severity.upper()

    channel = SEVERITY_CHANNEL_MAP.get(severity)
    message_template = SEVERITY_MESSAGE_MAP.get(severity)

    if not channel or not message_template:
        return None

    message = message_template.format(
        justification=final_decision.get(
            "justification", "Condition detected"
        ),
        final_eta=final_decision.get("final_eta", "unknown"),
    )

    if str(final_decision.get("decision_mode", "")).upper() == "MANUAL_OVERRIDE":
        message = f"[MANUAL OVERRIDE] {message}"

    return {
        "severity": severity,
        "channel": channel,
        "message": message,
    }


# Local test
if __name__ == "__main__":
    sample_decision = {
        "final_alert_severity": "WARNING",
        "final_eta": 25,
        "justification": "Rapid cloud formation detected",
    }

    payload = build_alert_payload(sample_decision)
    print(payload)
