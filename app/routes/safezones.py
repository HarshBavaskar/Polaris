from fastapi import APIRouter, Body
from pydantic import BaseModel, Field
from datetime import datetime, UTC
from app.database import safezones_collection

router = APIRouter(prefix="/safe-zones", tags=["Safe Zones"])


# =========================================================
# REQUEST MODELS (Swagger-Friendly)
# =========================================================

class AddManualSafeZoneRequest(BaseModel):
    lat: float = Field(..., description="Latitude of the safe zone")
    lng: float = Field(..., description="Longitude of the safe zone")
    radius: int = Field(300, description="Radius in meters")
    reason: str = Field(..., description="Why this zone is marked safe")
    author: str = Field(..., description="Authority setting this zone")


class DisableSafeZoneRequest(BaseModel):
    zone_id: str = Field(..., description="Zone ID to disable")


# =========================================================
# ADD MANUAL SAFE ZONE
# =========================================================
@router.post(
    "/manual/add",
    summary="Add Manual Safe Zone",
    description="Adds an authority-defined safe zone. Manual zones override auto zones for guidance."
)
def add_manual_safezone(payload: AddManualSafeZoneRequest):
    now = datetime.now(UTC)

    zone_id = f"MZ-{int(now.timestamp())}"

    doc = {
        "zone_id": zone_id,
        "lat": payload.lat,
        "lng": payload.lng,
        "radius": payload.radius,

        "confidence_score": 1.0,
        "confidence_level": "HIGH",

        "last_verified": now,
        "expires_at": None,   # Manual zones do not auto-expire

        "source": "MANUAL",
        "active": True,

        "reason": payload.reason,
        "author": payload.author
    }

    safezones_collection.insert_one(doc)

    return {
        "status": "added",
        "zone_id": zone_id,
        "source": "MANUAL"
    }


# =========================================================
# DISABLE MANUAL SAFE ZONE
# =========================================================
@router.post(
    "/manual/disable",
    summary="Disable Manual Safe Zone",
    description="Disables a manual safe zone without deleting it."
)
def disable_manual_safezone(payload: DisableSafeZoneRequest):
    result = safezones_collection.update_one(
        {
            "zone_id": payload.zone_id,
            "source": "MANUAL",
            "active": True
        },
        {
            "$set": {
                "active": False,
                "last_verified": datetime.now(UTC)
            }
        }
    )

    if result.matched_count == 0:
        return {
            "status": "not_found",
            "zone_id": payload.zone_id
        }

    return {
        "status": "disabled",
        "zone_id": payload.zone_id
    }
