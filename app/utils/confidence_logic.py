import statistics

def calculate_confidence(recent_risks, ai_level, final_level):
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

    # Clamp between 0 and 1
    confidence = max(0.0, min(1.0, confidence))
    return round(confidence, 2)
