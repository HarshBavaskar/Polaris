def estimate_eta(recent_risks, temporal_probability):
    """
    Estimate time to potential cloudburst based on risk trend
    and temporal AI confidence.
    """

    if len(recent_risks) < 3:
        return "UNKNOWN"

    # Calculate risk rate of change
    deltas = [
        recent_risks[i] - recent_risks[i - 1]
        for i in range(1, len(recent_risks))
    ]

    avg_rate = sum(deltas) / len(deltas)

    # If risk is not increasing
    if avg_rate <= 0:
        return "> 60 min"

    # Adjust urgency using temporal AI
    urgency = avg_rate * (1 + temporal_probability)

    if urgency > 0.08:
        return "< 10 min"
    elif urgency > 0.05:
        return "10–30 min"
    elif urgency > 0.02:
        return "30–60 min"
    else:
        return "> 60 min"
