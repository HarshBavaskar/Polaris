from fastapi import APIRouter
from app.database import alerts_collection

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
def get_alert_history(limit: int = 50, severity: str | None = None):
    """
    Returns alert history (latest first).
    Optional severity filter.
    """
    query = {}
    if severity:
        query["severity"] = severity.strip().upper()

    # Keep the endpoint safe for UI usage
    limit = max(1, min(limit, 1000))

    alerts = list(
        alerts_collection.find(
            query,
            {"_id": 0}
        )
        .sort("timestamp", -1)
        .limit(limit)
    )

    return alerts
