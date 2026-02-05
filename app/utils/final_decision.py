from app.database import overrides_collection

def build_final_decision(
    risk_level,
    confidence,
    eta,
    eta_confidence,
    alert_severity,
    justification,
):
    override = overrides_collection.find_one(
        {"active": True},
        sort=[("timestamp", -1)]
    )

    if override:
        return {
            "final_risk_level": override["risk_level"],
            "final_confidence": 1.0,
            "final_eta": override.get("eta", "UNKNOWN"),
            "final_eta_confidence": "HIGH",
            "final_alert_severity": override["alert_severity"],

            # 🔑 THIS IS THE CRITICAL FIX
            "decision_mode": "MANUAL_OVERRIDE",

            "justification": (
                f"Manual override by {override.get('author', 'Authority')}: "
                f"{override.get('reason', '')}"
            ),
        }

    return {
        "final_risk_level": risk_level,
        "final_confidence": confidence,
        "final_eta": eta,
        "final_eta_confidence": eta_confidence,
        "final_alert_severity": alert_severity,

        # 🔑 MUST EXIST ALWAYS
        "decision_mode": "AUTOMATED",

        "justification": justification,
    }
