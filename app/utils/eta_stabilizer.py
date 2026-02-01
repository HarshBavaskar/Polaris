ETA_ORDER = [
    "UNKNOWN",
    "> 60 min",
    "30–60 min",
    "10–30 min",
    "< 10 min"
]

def stabilize_eta(previous_eta, new_eta, persistence_count):
    if previous_eta is None:
        return new_eta, 1

    # ✅ SAME ETA → INCREASE PERSISTENCE
    if new_eta == previous_eta:
        return new_eta, persistence_count + 1

    prev_idx = ETA_ORDER.index(previous_eta)
    new_idx = ETA_ORDER.index(new_eta)

    # Escalation → immediate
    if new_idx > prev_idx:
        return new_eta, 1

    # De-escalation → needs persistence
    if persistence_count >= 3:
        return new_eta, 1

    # Otherwise hold previous ETA
    return previous_eta, persistence_count
