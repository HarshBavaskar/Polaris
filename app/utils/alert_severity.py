def determine_alert_severity(
    risk_level,
    confidence,
    eta,
    eta_confidence
):
    # Low overall certainty → no aggressive alerts
    if confidence < 0.5:
        return "INFO"

    # Highest severity only if ETA is short AND reliable
    if (
        risk_level == "IMMINENT"
        and eta == "< 10 min"
        and eta_confidence in ["HIGH", "MEDIUM"]
    ):
        return "EMERGENCY"

    # Strong alert but not emergency
    if (
        risk_level in ["IMMINENT", "WARNING"]
        and eta in ["< 10 min", "10–30 min"]
    ):
        return "ALERT"

    # Early caution
    if risk_level in ["WATCH", "WARNING"]:
        return "ADVISORY"

    return "INFO"
