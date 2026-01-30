def calculate_risk_trend(risk_values):
    """
    Determines how fast risk is increasing
    """
    if len(risk_values) < 2:
        return 0.0

    return risk_values[-1] - risk_values[0]


def is_sudden_spike(risk_values, threshold=0.25):
    """
    Detects sudden dangerous escalation
    """
    trend = calculate_risk_trend(risk_values)
    return trend >= threshold

from app.database import predictions_collection

def get_recent_risks(limit=5):
    """
    Gets last N risk scores
    """
    cursor = predictions_collection.find().sort("timestamp", -1).limit(limit)
    risks = [doc["risk_score"] for doc in reversed(list(cursor))]
    return risks
