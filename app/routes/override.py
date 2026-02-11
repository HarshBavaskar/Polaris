from fastapi import APIRouter
from datetime import datetime
from app.database import overrides_collection

router = APIRouter(prefix="/override", tags=["Authority Override"])


@router.post("/set")
def set_override(payload: dict):
    """
    Expected payload:
    {
      "risk_level": "WARNING",
      "alert_severity": "ALERT",
      "decision_mode": "MANUAL_OVERRIDE",
      "reason": "...",
      "author": "Authority"
    }
    """

    # Deactivate any existing override
    overrides_collection.update_many(
        {"active": True},
        {"$set": {"active": False}}
    )

    doc = {
        "risk_level": payload.get("risk_level"),
        "alert_severity": payload.get("alert_severity"),
        "decision_mode": "MANUAL_OVERRIDE",
        "reason": payload.get("reason"),
        "author": payload.get("author", "Authority"),
        "active": True,
        "timestamp": datetime.now()
    }

    overrides_collection.insert_one(doc)

    return {"status": "override_set"}


@router.post("/clear")
def clear_override():
    overrides_collection.update_many(
        {"active": True},
        {
            "$set": {
                "active": False,
                "cleared_at": datetime.now()
            }
        }
    )

    return {"status": "override_cleared"}


@router.get("/history")
def get_override_history():
    history = list(
        overrides_collection.find(
            {},
            {"_id": 0}
        ).sort("timestamp", -1)
    )
    return history


@router.get("/active")
def get_active_override():
    override = overrides_collection.find_one(
        {"active": True},
        {"_id": 0}
    )
    return override
