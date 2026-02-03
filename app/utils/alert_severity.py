def determine_alert_severity(
    risk_level,
    confidence,
    eta,
    eta_confidence,
    temporal_probability,
    override=None
):
    if override:
        return override["alert_severity"]

    if risk_level == "IMMINENT":
        return "EMERGENCY"

    if eta in ["0–30 min"] and confidence >= 0.8:
        return "EMERGENCY"

    if temporal_probability >= 0.75:
        return "EMERGENCY"

    if (
        risk_level == "WARNING"
        and confidence >= 0.7
        and eta in ["30–60 min"]
        and eta_confidence != "LOW"
    ):
        return "ALERT"

    if risk_level == "WATCH" and confidence >= 0.6:
        return "ADVISORY"

    return "INFO"
