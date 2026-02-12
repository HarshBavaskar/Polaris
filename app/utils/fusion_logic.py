from app.database import citizen_reports_collection
from datetime import datetime, timedelta


def recent_water_signal(zone_id, minutes=20):
    since = datetime.now() - timedelta(minutes=minutes)
    reports = list(citizen_reports_collection.find({
        "zone_id": zone_id,
        "type": {"$in": ["WATER_LEVEL", "FLOODING", "RAINFALL_INTENSITY"]},
        "timestamp": {"$gte": since}
    }))

    if not reports:
        return 0.0

    level_weight = {
        "LOW": 0.6,
        "MEDIUM": 1.0,
        "HIGH": 1.4,
        "SEVERE": 1.8,
        "CRITICAL": 2.0,
    }

    score = 0.0
    for report in reports:
        level = (report.get("level") or "MEDIUM").upper()
        score += level_weight.get(level, 1.0)

    return round(score, 2)


def fuse_risk(ai_level, zone_id):
    signal = recent_water_signal(zone_id)

    if signal >= 5.0:
        return "IMMINENT"
    if signal >= 3.0:
        return "WARNING" if ai_level in {"SAFE", "WATCH", "WARNING"} else ai_level
    if signal >= 1.5 and ai_level == "SAFE":
        return "WATCH"

    return ai_level
