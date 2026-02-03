from fastapi import APIRouter
from datetime import datetime, timezone
from app.database import overrides_collection

router = APIRouter(prefix="/override", tags=["Override"])

@router.post("/set")
def set_override(payload: dict):
    overrides_collection.update_many(
        {"active": True},
        {"$set": {"active": False}}
    )

    doc = {
        "active": True,
        "risk_level": payload["risk_level"],
        "alert_severity": payload["alert_severity"],
        "reason": payload.get("reason", ""),
        "author": payload.get("author", "Unknown"),
        "timestamp": datetime.now(timezone.utc),
    }

    overrides_collection.insert_one(doc)
    return {"status": "override_set"}

@router.post("/clear")
def clear_override():
    overrides_collection.update_many(
        {"active": True},
        {"$set": {"active": False}}
    )
    return {"status": "override_cleared"}


@router.get("/active")
def get_active_override():
    doc = overrides_collection.find_one(
        {"active": True},
        sort=[("timestamp", -1)]
    )

    if not doc:
        return {"active": False}

    doc["_id"] = str(doc["_id"])
    return doc
