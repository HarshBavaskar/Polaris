ETA_ORDER = [
    "> 60 min",
    "30–60 min",
    "10–30 min",
    "< 10 min"
]

def smooth_eta(previous_eta, new_eta):
    """
    Prevent ETA from oscillating due to numeric noise.
    """

    if previous_eta is None:
        return new_eta

    prev_idx = ETA_ORDER.index(previous_eta)
    new_idx = ETA_ORDER.index(new_eta)

    # Allow escalation immediately
    if new_idx > prev_idx:
        return new_eta

    # Block small de-escalations
    if prev_idx - new_idx == 1:
        return previous_eta

    return new_eta
