import statistics

def calculate_confidence(
    recent_risks,
    ai_level,
    final_level,
    ai_probability=None,
    temporal_probability=None,
    ensemble_score=None,
):
    """
    Confidence based on stability and agreement
    """
    confidence = 0.5  # base confidence

    # 1) Stability: low variance = higher confidence
    if len(recent_risks) >= 3:
        variance = statistics.pvariance(recent_risks)
        if variance < 0.01:
            confidence += 0.2
        elif variance < 0.03:
            confidence += 0.1

    # 2) Agreement between AI and fusion
    if ai_level == final_level:
        confidence += 0.2
    else:
        confidence -= 0.1

    # 3) Model agreement (CNN vs temporal) improves confidence
    if ai_probability is not None and temporal_probability is not None:
        gap = abs(ai_probability - temporal_probability)
        if gap <= 0.12:
            confidence += 0.08
        elif gap >= 0.35:
            confidence -= 0.06

    # 4) Decisive ensemble score boosts confidence slightly
    if ensemble_score is not None:
        if ensemble_score >= 0.82 or ensemble_score <= 0.18:
            confidence += 0.05

    # Clamp between 0 and 1
    confidence = max(0.0, min(1.0, confidence))
    return round(confidence, 2)
