def determine_eta_confidence(recent_risks, temporal_probability, confidence):
    """
    Determines how reliable the ETA estimate is.
    """

    # No history → low confidence
    if len(recent_risks) < 3:
        return "LOW"

    # Strong temporal signal + high system confidence
    if temporal_probability >= 0.7 and confidence >= 0.8:
        return "HIGH"

    # Moderate trend
    if temporal_probability >= 0.4 and confidence >= 0.6:
        return "MEDIUM"

    return "LOW"
