from fastapi import APIRouter
from datetime import datetime

from app.database import safezones_collection
from app.utils.safezone_detector import (
    filter_low_risk,
    filter_historical,
    filter_stable,
    cluster_safezones,
    rank_safezones,
    persist_safezones
)

router = APIRouter(prefix="/map", tags=["Map"])


# =========================================================
# AUTO SAFE ZONE DETECTION (WRITE + RETURN)
# =========================================================
@router.get(
    "/safe-zones/auto",
    summary="Auto-detected Safe Zones",
    description="Runs safe-zone detection logic, persists valid zones, and returns results."
)
def get_auto_safezones():
    # -----------------------------
    # MOCK DATA (REPLACE LATER)
    # -----------------------------
    live_points = [
        {"lat": 19.0760, "lng": 72.8777, "risk_score": 0.2},
        {"lat": 19.0780, "lng": 72.8800, "risk_score": 0.25},
        {"lat": 19.0700, "lng": 72.8700, "risk_score": 0.6},
    ]

    historical_events = [
        {"lat": 19.0705, "lng": 72.8710}
    ]

    risk_history = {
        "19.0760_72.8777": [0.30, 0.28, 0.25, 0.22],
        "19.0780_72.8800": [0.35, 0.30, 0.27, 0.25],
    }

    # -----------------------------
    # PIPELINE
    # -----------------------------
    low = filter_low_risk(live_points)
    hist = filter_historical(low, historical_events)
    stable = filter_stable(hist, risk_history)

    if not stable:
        return []

    clusters = cluster_safezones(stable)
    if not clusters:
        return []

    ranked = rank_safezones(clusters)
    if not ranked:
        return []

    # -----------------------------
    # PERSIST (AUTO ONLY)
    # -----------------------------
    persist_safezones(ranked, safezones_collection)

    return ranked


# =========================================================
# READ-ONLY SAFE ZONES (DASHBOARD CONTRACT)
# =========================================================
@router.get(
    "/safe-zones",
    tags=["Map"],
    summary="Active Safe Zones",
    description="Returns active, non-expired safe zones for dashboard and alerts."
)
def get_active_safezones():
    now = datetime.now()

    zones = list(
        safezones_collection.find(
            {
                "active": True,
                "$or": [
                    {"source": "MANUAL"},
                    {"expires_at": {"$gt": now}}
                ]
            },
            {"_id": 0}
        )
    )

    # Manual zones first (override order for guidance)
    zones.sort(key=lambda z: 0 if z["source"] == "MANUAL" else 1)

    return zones if zones else []



# =========================================================
# HISTORICAL INCIDENTS (OPTIONAL MAP LAYER)
# =========================================================
@router.get(
    "/historical-incidents",
    summary="Historical Cloudburst Incidents",
    description="Returns historical cloudburst/flood points for map overlay."
)
def get_historical_incidents():
    # Replace later with DB-backed incidents
    return [
        {
            "lat": 19.0705,
            "lng": 72.8710,
            "year": 2021,
            "severity": "HIGH"
        },
        {
            "lat": 19.0820,
            "lng": 72.8890,
            "year": 2019,
            "severity": "MEDIUM"
        }
    ]
