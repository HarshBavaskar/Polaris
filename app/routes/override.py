from fastapi import APIRouter
from datetime import datetime
from app.database import overrides_collection, alerts_collection
from app.notifications.alert_engine import build_alert_payload
from app.notifications.deliver import deliver
from app.notifications.valkey_pub import publish_decision

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

    requested_signature = {
        "risk_level": (payload.get("risk_level") or "").strip().upper(),
        "alert_severity": (payload.get("alert_severity") or "").strip().upper(),
        "reason": (payload.get("reason") or "").strip(),
        "author": (payload.get("author") or "Authority").strip(),
    }

    # If the same override is already active, skip duplicate set/dispatch.
    active_override = overrides_collection.find_one({"active": True})
    if active_override:
        active_signature = {
            "risk_level": (active_override.get("risk_level") or "").strip().upper(),
            "alert_severity": (active_override.get("alert_severity") or "").strip().upper(),
            "reason": (active_override.get("reason") or "").strip(),
            "author": (active_override.get("author") or "Authority").strip(),
        }
        if active_signature == requested_signature:
            return {"status": "override_unchanged", "alert_dispatch": "duplicate_ignored"}

    # Deactivate any existing override
    overrides_collection.update_many(
        {"active": True},
        {"$set": {"active": False}}
    )

    doc = {
        "risk_level": requested_signature["risk_level"],
        "alert_severity": requested_signature["alert_severity"],
        "decision_mode": "MANUAL_OVERRIDE",
        "reason": requested_signature["reason"],
        "author": requested_signature["author"],
        "active": True,
        "timestamp": datetime.now(),
        "signature": requested_signature,
    }

    overrides_collection.insert_one(doc)

    # Push manual override into the same decision/alert pipeline immediately.
    final_decision = {
        "final_risk_level": doc.get("risk_level"),
        "final_confidence": 1.0,
        "final_eta": "UNKNOWN",
        "final_eta_confidence": "HIGH",
        "final_alert_severity": doc.get("alert_severity"),
        "decision_mode": "MANUAL_OVERRIDE",
        "justification": f"Manual override by {doc.get('author', 'Authority')}: {doc.get('reason', '')}",
    }

    alert_status = "no_alert"
    try:
        publish_decision(final_decision)
        alert_payload = build_alert_payload(final_decision)
        if alert_payload:
            latest_manual_alert = alerts_collection.find_one(
                {"source": "MANUAL_OVERRIDE"},
                sort=[("timestamp", -1)],
            )
            if latest_manual_alert and \
               latest_manual_alert.get("severity") == alert_payload.get("severity") and \
               latest_manual_alert.get("message") == alert_payload.get("message"):
                return {"status": "override_set", "alert_dispatch": "duplicate_ignored"}

            alert_doc = {
                "channel": alert_payload.get("channel"),
                "severity": alert_payload.get("severity"),
                "message": alert_payload.get("message"),
                "timestamp": datetime.now(),
                "status": "queued",
                "source": "MANUAL_OVERRIDE",
            }
            result = alerts_collection.insert_one(alert_doc)
            delivery_result = deliver(alert_payload)
            new_status = "sent" if delivery_result.get("ok") else "failed"
            alerts_collection.update_one(
                {"_id": result.inserted_id},
                {"$set": {"status": new_status, "delivery": delivery_result}},
            )
            alert_status = new_status
    except Exception:
        alert_status = "dispatch_failed"

    return {"status": "override_set", "alert_dispatch": alert_status}


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
