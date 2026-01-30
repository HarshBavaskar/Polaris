def normalize(value, min_val, max_val):
    if value < min_val:
        return 0.0
    if value > max_val:
        return 1.0
    return (value - min_val) / (max_val - min_val)


def calculate_risk(features):
    """
    Convert features into a risk score (0 to 1)
    """

    # Normalize features
    brightness_risk = 1 - normalize(features["brightness"], 50, 200)
    edge_risk = normalize(features["edge_density"], 0.05, 0.35)
    entropy_risk = normalize(features["entropy"], 4.0, 7.5)

    # Weighted sum
    risk_score = (
        0.4 * brightness_risk +
        0.3 * edge_risk +
        0.3 * entropy_risk
    )

    return round(risk_score, 3)


def risk_level(risk_score):
    if risk_score < 0.4:
        return "SAFE"
    elif risk_score < 0.65:
        return "WATCH"
    elif risk_score < 0.8:
        return "WARNING"
    else:
        return "IMMINENT"
