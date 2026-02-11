from fastapi import APIRouter, Form
from datetime import datetime
from app.database import feedback_collection

router = APIRouter(prefix="/authority/feedback", tags=["Authority Feedback"])

@router.post("/")
async def submit_feedback(
    prediction_id: str = Form(...),
    label: str = Form(...)
):
    doc = {
        "prediction_id": prediction_id,
        "label": label,  # FALSE_POSITIVE | TRUE_POSITIVE | LATE
        "timestamp": datetime.now()
    }

    feedback_collection.insert_one(doc)

    return {
        "message": "Feedback recorded",
        "label": label
    }
