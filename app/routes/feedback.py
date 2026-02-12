from fastapi import APIRouter, Form
from datetime import datetime
from bson import ObjectId
from app.database import feedback_collection, predictions_collection, active_learning_collection
from app.services.ml_admin_service import maybe_trigger_auto_retrain

router = APIRouter(prefix="/authority/feedback", tags=["Authority Feedback"])

@router.post("/")
async def submit_feedback(
    prediction_id: str = Form(...),
    label: str = Form(...)
):
    normalized_label = (label or "").strip().upper()
    doc = {
        "prediction_id": prediction_id,
        "label": normalized_label,  # FALSE_POSITIVE | TRUE_POSITIVE | LATE
        "timestamp": datetime.now()
    }

    feedback_collection.insert_one(doc)
    auto_job = None
    try:
        pid = ObjectId(prediction_id)
        predictions_collection.update_one(
            {"_id": pid},
            {"$set": {
                "authority_feedback": normalized_label,
                "authority_feedback_at": datetime.now(),
            }}
        )
        active_learning_collection.update_one(
            {"prediction_id": pid},
            {"$set": {"status": "LABELED", "labeled_at": datetime.now(), "label": normalized_label}}
        )
    except Exception:
        # Keep endpoint non-blocking even if prediction_id is not an ObjectId.
        pass
    try:
        feedback_total = feedback_collection.count_documents({})
        auto_job = maybe_trigger_auto_retrain(feedback_total)
    except Exception:
        auto_job = None

    return {
        "message": "Feedback recorded",
        "label": normalized_label,
        "auto_retrain": "started" if auto_job else "not_triggered",
    }


@router.get("/active-learning/queue")
def get_active_learning_queue(limit: int = 50):
    items = list(
        active_learning_collection.find(
            {"status": "PENDING_LABEL"},
            {"_id": 0}
        )
        .sort("queued_at", -1)
        .limit(limit)
    )
    return items


@router.get("/active-learning/stats")
def get_active_learning_stats():
    pending = active_learning_collection.count_documents({"status": "PENDING_LABEL"})
    labeled = active_learning_collection.count_documents({"status": "LABELED"})
    return {
        "pending_label_queue": pending,
        "labeled_samples": labeled,
    }
