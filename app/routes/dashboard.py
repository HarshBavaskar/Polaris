from datetime import datetime, timedelta
from math import asin, cos, radians, sin, sqrt

from bson import ObjectId
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from app.database import (
    help_requests_collection,
    predictions_collection,
    rescue_teams_collection,
    team_notifications_collection,
)

router = APIRouter(prefix="/dashboard", tags=["Dashboard"])


def _to_iso(value):
    if isinstance(value, datetime):
        return value.isoformat()
    return value


def _serialize_help_request(doc: dict) -> dict:
    return {
        "request_id": str(doc.get("_id")),
        "category": doc.get("category"),
        "contact_number": doc.get("contact_number"),
        "lat": doc.get("lat"),
        "lng": doc.get("lng"),
        "status": doc.get("status", "OPEN"),
        "source": doc.get("source", "CITIZEN_APP"),
        "assigned_team_id": doc.get("assigned_team_id"),
        "assigned_by": doc.get("assigned_by"),
        "assignment_notes": doc.get("assignment_notes"),
        "created_at": _to_iso(doc.get("created_at")),
        "updated_at": _to_iso(doc.get("updated_at")),
        "assigned_at": _to_iso(doc.get("assigned_at")),
    }


def _serialize_team(doc: dict) -> dict:
    return {
        "team_id": doc.get("team_id"),
        "name": doc.get("name"),
        "members_count": int(doc.get("members_count") or 0),
        "status": doc.get("status", "AVAILABLE"),
        "lat": doc.get("lat"),
        "lng": doc.get("lng"),
        "contact_number": doc.get("contact_number"),
        "assigned_request_id": doc.get("assigned_request_id"),
        "updated_at": _to_iso(doc.get("updated_at")),
        "last_notified_at": _to_iso(doc.get("last_notified_at")),
    }


def _distance_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    # Haversine distance in kilometers.
    r = 6371.0
    dlat = radians(lat2 - lat1)
    dlng = radians(lng2 - lng1)
    a = (
        sin(dlat / 2) ** 2
        + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlng / 2) ** 2
    )
    return 2 * r * asin(sqrt(a))


def _seed_default_teams_if_empty() -> None:
    if rescue_teams_collection.estimated_document_count() > 0:
        return

    now = datetime.now()
    rescue_teams_collection.insert_many(
        [
            {
                "team_id": "TEAM-01",
                "name": "River Watch Unit",
                "members_count": 6,
                "status": "AVAILABLE",
                "lat": 19.0896,
                "lng": 72.8656,
                "contact_number": "1001",
                "updated_at": now,
            },
            {
                "team_id": "TEAM-02",
                "name": "Medical Support",
                "members_count": 4,
                "status": "AVAILABLE",
                "lat": 19.0623,
                "lng": 72.8792,
                "contact_number": "1002",
                "updated_at": now,
            },
            {
                "team_id": "TEAM-03",
                "name": "Evacuation Squad",
                "members_count": 8,
                "status": "DEPLOYED",
                "lat": 19.1044,
                "lng": 72.9012,
                "contact_number": "1003",
                "updated_at": now,
            },
        ]
    )


class TeamUpsertRequest(BaseModel):
    team_id: str = Field(..., min_length=2, max_length=40)
    name: str = Field(..., min_length=2, max_length=80)
    members_count: int = Field(..., ge=1, le=100)
    status: str = Field(default="AVAILABLE")
    lat: float
    lng: float
    contact_number: str | None = Field(default=None, max_length=30)


class AssignTeamRequest(BaseModel):
    team_id: str = Field(..., min_length=2, max_length=40)
    author: str = Field(default="Authority", min_length=2, max_length=60)
    notes: str | None = Field(default=None, max_length=200)


class NotifyNearbyRequest(BaseModel):
    radius_km: float = Field(default=5.0, gt=0.2, le=50.0)
    author: str = Field(default="Authority", min_length=2, max_length=60)
    message: str | None = Field(default=None, max_length=200)


@router.get("/risk-timeseries")
def risk_timeseries(minutes: int = 60):
    since = datetime.now() - timedelta(minutes=minutes)

    cursor = predictions_collection.find(
        {"timestamp": {"$gte": since}},
        {"_id": 0, "timestamp": 1, "risk_score": 1, "ensemble_score": 1, "risk_level": 1},
    ).sort("timestamp", 1)

    data = []
    for doc in cursor:
        data.append(
            {
                "time": doc["timestamp"],
                # Keep both keys for backward compatibility with existing clients.
                "risk_score": doc.get("risk_score", 0),
                "risk": doc.get("risk_score", 0),
                "ensemble_score": doc.get("ensemble_score"),
                "level": doc["risk_level"],
            }
        )

    return data


@router.get("/confidence-timeseries")
def confidence_timeseries(minutes: int = 60):
    since = datetime.now() - timedelta(minutes=minutes)

    cursor = predictions_collection.find(
        {"timestamp": {"$gte": since}},
        {"_id": 0, "timestamp": 1, "confidence": 1},
    ).sort("timestamp", 1)

    data = []
    for doc in cursor:
        if "confidence" in doc:
            data.append({"time": doc["timestamp"], "confidence": doc["confidence"]})

    return data


@router.get("/current-status")
def current_status():
    latest = predictions_collection.find_one(sort=[("timestamp", -1)])

    if not latest:
        return {"status": "NO_DATA"}

    return {
        "risk_level": latest.get("risk_level"),
        "risk_score": latest.get("risk_score"),
        "confidence": latest.get("confidence"),
        "timestamp": latest.get("timestamp"),
    }


@router.get("/eta-timeseries")
def eta_timeseries(minutes: int = 60):
    since = datetime.now() - timedelta(minutes=minutes)

    cursor = predictions_collection.find(
        {"timestamp": {"$gte": since}},
        {"_id": 0, "timestamp": 1, "eta": 1},
    ).sort("timestamp", 1)

    data = []
    for doc in cursor:
        if "eta" in doc:
            data.append({"time": doc["timestamp"], "eta": doc["eta"]})

    return data


@router.get("/help-requests")
def get_help_requests(limit: int = 100, status: str = "OPEN"):
    status_upper = status.strip().upper()
    query = {}
    if status_upper != "ALL":
        query["status"] = status_upper

    docs = list(
        help_requests_collection.find(query).sort("created_at", -1).limit(max(1, min(limit, 300)))
    )
    return [_serialize_help_request(doc) for doc in docs]


@router.post("/teams/upsert")
def upsert_team(payload: TeamUpsertRequest):
    status = payload.status.strip().upper()
    if status not in {"AVAILABLE", "DEPLOYED", "OFFLINE"}:
        raise HTTPException(status_code=400, detail="Invalid team status")

    now = datetime.now()
    rescue_teams_collection.update_one(
        {"team_id": payload.team_id.strip().upper()},
        {
            "$set": {
                "team_id": payload.team_id.strip().upper(),
                "name": payload.name.strip(),
                "members_count": payload.members_count,
                "status": status,
                "lat": payload.lat,
                "lng": payload.lng,
                "contact_number": (payload.contact_number or "").strip() or None,
                "updated_at": now,
            },
            "$setOnInsert": {"created_at": now},
        },
        upsert=True,
    )
    return {"status": "saved", "team_id": payload.team_id.strip().upper()}


@router.post("/help-requests/{request_id}/assign-team")
def assign_team_to_help_request(request_id: str, payload: AssignTeamRequest):
    team_id = payload.team_id.strip().upper()
    team = rescue_teams_collection.find_one({"team_id": team_id})
    if not team:
        raise HTTPException(status_code=404, detail=f"Team not found: {team_id}")

    try:
        req_object_id = ObjectId(request_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid request_id") from None

    now = datetime.now()
    updated = help_requests_collection.update_one(
        {"_id": req_object_id},
        {
            "$set": {
                "status": "ASSIGNED",
                "assigned_team_id": team_id,
                "assigned_by": payload.author.strip(),
                "assignment_notes": (payload.notes or "").strip() or None,
                "assigned_at": now,
                "updated_at": now,
            }
        },
    )

    if updated.matched_count == 0:
        raise HTTPException(status_code=404, detail=f"Help request not found: {request_id}")

    rescue_teams_collection.update_one(
        {"team_id": team_id},
        {
            "$set": {
                "status": "DEPLOYED",
                "assigned_request_id": request_id,
                "updated_at": now,
            }
        },
    )

    return {"status": "assigned", "request_id": request_id, "team_id": team_id}


@router.post("/help-requests/{request_id}/notify-nearby")
def notify_nearby_teams(request_id: str, payload: NotifyNearbyRequest):
    try:
        req_object_id = ObjectId(request_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid request_id") from None

    req_doc = help_requests_collection.find_one({"_id": req_object_id})
    if not req_doc:
        raise HTTPException(status_code=404, detail=f"Help request not found: {request_id}")

    req_lat = req_doc.get("lat")
    req_lng = req_doc.get("lng")
    if req_lat is None or req_lng is None:
        raise HTTPException(
            status_code=400,
            detail="Cannot notify nearby teams: request has no location",
        )

    teams = list(
        rescue_teams_collection.find(
            {"status": {"$in": ["AVAILABLE", "DEPLOYED"]}},
        )
    )

    now = datetime.now()
    notifications = []
    notified = []
    for team in teams:
        team_lat = team.get("lat")
        team_lng = team.get("lng")
        if team_lat is None or team_lng is None:
            continue
        distance_km = _distance_km(float(req_lat), float(req_lng), float(team_lat), float(team_lng))
        if distance_km > payload.radius_km:
            continue

        team_id = str(team.get("team_id"))
        message = payload.message or (
            f"Nearby help request ({req_doc.get('category', 'General')}) is open."
        )
        notifications.append(
            {
                "team_id": team_id,
                "request_id": request_id,
                "distance_km": round(distance_km, 3),
                "status": "SENT",
                "message": message,
                "author": payload.author.strip(),
                "created_at": now,
            }
        )
        notified.append({"team_id": team_id, "distance_km": round(distance_km, 3)})

        rescue_teams_collection.update_one(
            {"team_id": team_id},
            {"$set": {"last_notified_at": now, "updated_at": now}},
        )

    if notifications:
        team_notifications_collection.insert_many(notifications)

    return {
        "status": "notified",
        "request_id": request_id,
        "radius_km": payload.radius_km,
        "notified_count": len(notified),
        "teams": notified,
    }


@router.get("/teams/snapshot")
def get_teams_snapshot():
    _seed_default_teams_if_empty()

    teams = list(rescue_teams_collection.find({}).sort("team_id", 1))
    open_or_assigned_requests = list(
        help_requests_collection.find(
            {"status": {"$in": ["OPEN", "ASSIGNED"]}}
        ).sort("created_at", -1)
    )

    total_teams = len(teams)
    available = sum(1 for t in teams if str(t.get("status", "")).upper() == "AVAILABLE")
    deployed = sum(1 for t in teams if str(t.get("status", "")).upper() == "DEPLOYED")
    offline = sum(1 for t in teams if str(t.get("status", "")).upper() == "OFFLINE")
    total_members = sum(int(t.get("members_count") or 0) for t in teams)
    open_requests = sum(
        1 for r in open_or_assigned_requests if str(r.get("status", "")).upper() == "OPEN"
    )
    assigned_requests = sum(
        1 for r in open_or_assigned_requests if str(r.get("status", "")).upper() == "ASSIGNED"
    )
    notifications_sent = team_notifications_collection.count_documents({})

    return {
        "teams": [_serialize_team(t) for t in teams],
        "help_requests": [_serialize_help_request(r) for r in open_or_assigned_requests],
        "stats": {
            "total_teams": total_teams,
            "available_teams": available,
            "deployed_teams": deployed,
            "offline_teams": offline,
            "total_members": total_members,
            "open_help_requests": open_requests,
            "assigned_help_requests": assigned_requests,
            "notifications_sent": notifications_sent,
        },
    }
