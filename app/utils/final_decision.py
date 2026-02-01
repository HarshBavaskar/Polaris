LEVEL_ORDER = ["SAFE", "WATCH", "WARNING", "IMMINENT"]

def determine_final_risk(
    rule_level,
    cnn_level,
    temporal_level,
    confidence
):
    # Pick highest suggested risk
    candidate = max(
        rule_level,
        cnn_level,
        temporal_level,
        key=lambda x: LEVEL_ORDER.index(x)
    )

    # Safety gate: low confidence cannot jump to IMMINENT
    if confidence < 0.5 and candidate == "IMMINENT":
        return "WARNING"

    return candidate

def determine_final_eta(eta, eta_confidence):
    return eta

def compute_final_confidence(
    base_confidence,
    cnn_probability,
    temporal_probability
    ):
    boost = 0.0

    if cnn_probability > 0.6:
        boost += 0.05
    if temporal_probability > 0.6:
        boost += 0.1

    final_conf = base_confidence + boost
    return round(min(final_conf, 1.0), 2)

def determine_decision_state(alert_severity):
    if alert_severity in ["ALERT", "EMERGENCY"]:
        return "ACTIONABLE"
    return "MONITOR"

def build_final_decision(
    rule_level,
    cnn_level,
    temporal_level,
    confidence,
    eta,
    eta_confidence,
    alert_severity,
    cnn_probability,
    temporal_probability,
    justification
):
    final_risk = determine_final_risk(
        rule_level,
        cnn_level,
        temporal_level,
        confidence
    )

    final_eta = determine_final_eta(
        eta,
        eta_confidence
    )

    final_confidence = compute_final_confidence(
        confidence,
        cnn_probability,
        temporal_probability
    )

    decision_state = determine_decision_state(
        alert_severity
    )

    return {
        "final_risk_level": final_risk,
        "final_confidence": final_confidence,
        "final_eta": final_eta,
        "final_eta_confidence": eta_confidence,
        "final_alert_severity": alert_severity,
        "decision_state": decision_state,
        "justification": justification
    }
