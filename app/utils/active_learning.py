from datetime import datetime
from bson import ObjectId

from app.database import feedback_collection, active_learning_collection


def _clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def feedback_bias(window: int = 200) -> float:
    """
    Learns from authority feedback:
    - FALSE_POSITIVE lowers risk slightly
    - LATE raises risk slightly
    - TRUE_POSITIVE gives a small positive weight
    """
    docs = list(
        feedback_collection.find({}, {"_id": 0, "label": 1})
        .sort("timestamp", -1)
        .limit(window)
    )
    if not docs:
        return 0.0

    total = len(docs)
    false_positive = sum(1 for d in docs if (d.get("label") or "").upper() == "FALSE_POSITIVE")
    late = sum(1 for d in docs if (d.get("label") or "").upper() == "LATE")
    true_positive = sum(1 for d in docs if (d.get("label") or "").upper() == "TRUE_POSITIVE")

    bias = (
        (-0.10 * (false_positive / total)) +
        (0.12 * (late / total)) +
        (0.04 * (true_positive / total))
    )
    return round(_clamp(bias, -0.08, 0.08), 3)


def should_queue_for_active_learning(
    *,
    confidence: float,
    ensemble_score: float,
    cnn_probability: float,
    temporal_probability: float,
) -> bool:
    low_confidence = confidence < 0.67
    model_disagreement = abs(cnn_probability - temporal_probability) >= 0.30
    near_boundary = 0.45 <= ensemble_score <= 0.78
    return low_confidence or model_disagreement or near_boundary


def queue_active_learning_sample(
    *,
    prediction_id,
    image_path: str,
    risk_score: float,
    ensemble_score: float,
    confidence: float,
    cnn_probability: float,
    temporal_probability: float,
    features: dict,
) -> None:
    if prediction_id is None:
        return

    pid = prediction_id if isinstance(prediction_id, ObjectId) else ObjectId(str(prediction_id))

    active_learning_collection.update_one(
        {"prediction_id": pid},
        {
            "$setOnInsert": {
                "prediction_id": pid,
                "image_path": image_path,
                "queued_at": datetime.now(),
            },
            "$set": {
                "status": "PENDING_LABEL",
                "risk_score": risk_score,
                "ensemble_score": ensemble_score,
                "confidence": confidence,
                "cnn_probability": cnn_probability,
                "temporal_probability": temporal_probability,
                "features": {
                    "brightness": features.get("brightness"),
                    "edge_density": features.get("edge_density"),
                    "entropy": features.get("entropy"),
                },
            },
        },
        upsert=True,
    )
