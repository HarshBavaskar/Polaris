from fastapi import APIRouter
from app.database import predictions_collection
from datetime import datetime, timedelta

router = APIRouter(prefix="/dashboard", tags=["Dashboard"])
@router.get("/risk-timeseries")  #Risk Time-Series Endpoint
def risk_timeseries(minutes: int = 60):
    since = datetime.utcnow() - timedelta(minutes=minutes)

    cursor = predictions_collection.find(
        {"timestamp": {"$gte": since}},
        {"_id": 0, "timestamp": 1, "risk_score": 1, "risk_level": 1}
    ).sort("timestamp", 1)

    data = []
    for doc in cursor:
        data.append({
            "time": doc["timestamp"],
            "risk": doc["risk_score"],
            "level": doc["risk_level"]
        })

    return data

@router.get("/confidence-timeseries")    #Confidence Time-Series Endpoint
def confidence_timeseries(minutes: int = 60):
    since = datetime.utcnow() - timedelta(minutes=minutes)

    cursor = predictions_collection.find(
        {"timestamp": {"$gte": since}},
        {"_id": 0, "timestamp": 1, "confidence": 1}
    ).sort("timestamp", 1)

    data = []
    for doc in cursor:
        if "confidence" in doc:
            data.append({
                "time": doc["timestamp"],
                "confidence": doc["confidence"]
            })

    return data

@router.get("/current-status")    #Current Status Endpoint
def current_status():
    latest = predictions_collection.find_one(
        sort=[("timestamp", -1)]
    )

    if not latest:
        return {"status": "NO_DATA"}

    return {
        "risk_level": latest.get("risk_level"),
        "risk_score": latest.get("risk_score"),
        "confidence": latest.get("confidence"),
        "timestamp": latest.get("timestamp")
    }

@router.get("/eta-timeseries")
def eta_timeseries(minutes: int = 60):
    since = datetime.utcnow() - timedelta(minutes=minutes)

    cursor = predictions_collection.find(
        {"timestamp": {"$gte": since}},
        {"_id": 0, "timestamp": 1, "eta": 1}
    ).sort("timestamp", 1)

    data = []
    for doc in cursor:
        if "eta" in doc:
            data.append({
                "time": doc["timestamp"],
                "eta": doc["eta"]
            })

    return data
