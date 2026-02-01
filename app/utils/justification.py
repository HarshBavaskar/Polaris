def generate_authority_justification(
    risk_level,
    confidence,
    eta,
    eta_confidence,
    ai_probability,
    temporal_probability
):
    reasons = []

    reasons.append(f"Current risk level assessed as {risk_level}.")

    if temporal_probability > 0.6:
        reasons.append(
            "Temporal AI detected rapid escalation in conditions over recent observations."
        )

    if ai_probability > 0.6:
        reasons.append(
            "Visual AI identified cloud patterns associated with high-intensity rainfall."
        )

    if eta != "UNKNOWN":
        reasons.append(
            f"Estimated time to potential cloudburst is {eta} "
            f"(ETA confidence: {eta_confidence})."
        )

    reasons.append(f"Overall system confidence is {int(confidence * 100)}%.")

    return " ".join(reasons)
