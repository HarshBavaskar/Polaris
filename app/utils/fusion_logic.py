from app.database import citizen_reports_collection
from datetime import datetime, timedelta


def recent_water_reports(zone_id, minutes=15):
    since = datetime.utcnow() - timedelta(minutes=minutes)
    return citizen_reports_collection.count_documents({
        "zone_id": zone_id,
        "type": "WATER_LEVEL",
        "timestamp": {"$gte": since}
    })


def fuse_risk(ai_level, zone_id):
    reports = recent_water_reports(zone_id)

    if reports >= 3:
        return "IMMINENT"

    return ai_level
