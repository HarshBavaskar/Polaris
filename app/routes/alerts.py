from fastapi import APIRouter
from app.database import alerts_collection
from datetime import datetime

router = APIRouter(prefix="/alerts", tags=["Alerts"])


@router.get("/latest")
def get_latest_alert():
    """
    Returns the most recent alert (single object).
    Returns {} if no alerts exist.
    """

    alert = alerts_collection.find_one(
        {},
        sort=[("timestamp", -1)],
        projection={"_id": 0}
    )

    if not alert:
        return {}

    return alert


@router.get("/history")
def get_alert_history(limit: int = 50):
    """
    Returns alert history (latest first)
    """

    alerts = list(
        alerts_collection.find(
            {},
            {"_id": 0}
        )
        .sort("timestamp", -1)
        .limit(limit)
    )

    return alerts
