def _clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def level_from_score(score: float) -> str:
    if score < 0.35:
        return "SAFE"
    if score < 0.55:
        return "WATCH"
    if score < 0.75:
        return "WARNING"
    return "IMMINENT"


def compute_ensemble_score(
    rule_risk_score: float,
    cnn_probability: float,
    temporal_probability: float,
    recent_risks: list[float],
    *,
    feedback_bias: float = 0.0,
    sudden_spike: bool = False,
) -> float:
    """
    Weighted ensemble score from rule-based features + CNN + temporal model.
    This is intentionally conservative and adds small boosts/penalties only.
    """
    base = (
        (0.45 * rule_risk_score) +
        (0.35 * cnn_probability) +
        (0.20 * temporal_probability)
    )

    trend_boost = 0.0
    if len(recent_risks) >= 3:
        trend = recent_risks[-1] - recent_risks[0]
        trend_boost = _clamp(trend * 0.20, -0.08, 0.12)

    model_gap = abs(cnn_probability - temporal_probability)
    agreement_adjustment = 0.03 if model_gap <= 0.15 else (-0.02 if model_gap >= 0.40 else 0.0)
    spike_boost = 0.07 if sudden_spike else 0.0

    score = base + trend_boost + agreement_adjustment + spike_boost + feedback_bias
    return round(_clamp(score, 0.0, 1.0), 3)
