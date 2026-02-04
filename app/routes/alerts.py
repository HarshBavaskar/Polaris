from fastapi import APIRouter
from app.database import alerts_collection

router = APIRouter(prefix="/alerts", tags=["Alerts"])

@router.get("/latest")
def get_latest_alerts():
    docs = list(
        alerts_collection.find(
            {"active": True},
            {"_id": 0}
        ).sort("timestamp", -1)
    )
    return docs

@router.get("/history")
def get_alert_history(limit: int = 50):
    docs = list(
        alerts_collection.find(
            {},
            {"_id": 0}
        ).sort("timestamp", -1).limit(limit)
    )
    return docs
