from datetime import datetime
import os

from bson import ObjectId
from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from fastapi.responses import FileResponse
from pydantic import BaseModel, Field

from app.auth.jwt_handler import require_authority
from app.config import get_settings
from app.database import citizen_reports_collection, help_requests_collection
from app.upload_security import save_image_upload

router = APIRouter(prefix="/input/citizen", tags=["Citizen Inputs"])

settings = get_settings()
UPLOAD_DIR = settings.citizen_upload_dir
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)


class CitizenReviewRequest(BaseModel):
    report_id: str = Field(..., description="MongoDB ObjectId of report")
    action: str = Field(..., description="APPROVE or REJECT")
    verifier: str = Field("Authority", description="Name of verifier")
    notes: str | None = Field(None, description="Optional review note")


@router.post("/image")
async def citizen_image(
    zone_id: str = Form(...),
    image: UploadFile = File(...)
):
    timestamp = datetime.now()
    filename, filepath = await save_image_upload(
        image,
        target_dir=UPLOAD_DIR,
        max_upload_bytes=settings.max_upload_bytes,
    )

    doc = {
        "zone_id": zone_id,
        "type": "IMAGE",
        "filename": filename,
        "filepath": filepath,
        "timestamp": timestamp,
        "verified": False
    }

    citizen_reports_collection.insert_one(doc)

    return {
        "message": "Citizen image received",
        "zone_id": zone_id
    }


@router.post("/water-level")
async def citizen_water_level(
    zone_id: str = Form(...),
    level: str = Form(...)
):
    timestamp = datetime.now()

    doc = {
        "zone_id": zone_id,
        "type": "WATER_LEVEL",
        "level": level,
        "timestamp": timestamp,
        "verified": False
    }

    citizen_reports_collection.insert_one(doc)

    return {
        "message": "Water level report received",
        "zone_id": zone_id,
        "level": level
    }


@router.post("/help-request")
async def citizen_help_request(
    category: str = Form(...),
    contact_number: str = Form(...),
    lat: float | None = Form(None),
    lng: float | None = Form(None),
):
    normalized_category = category.strip()
    normalized_contact = contact_number.strip()

    if not normalized_category:
        return {"status": "error", "message": "category is required"}
    if not normalized_contact:
        return {"status": "error", "message": "contact_number is required"}

    timestamp = datetime.now()
    doc = {
        "category": normalized_category,
        "contact_number": normalized_contact,
        "lat": lat,
        "lng": lng,
        "status": "OPEN",
        "source": "CITIZEN_APP",
        "created_at": timestamp,
        "updated_at": timestamp,
    }

    result = help_requests_collection.insert_one(doc)
    return {
        "status": "submitted",
        "request_id": str(result.inserted_id),
        "created_at": timestamp,
    }


@router.get("/help-request/{request_id}")
def get_help_request_status(request_id: str):
    try:
        object_id = ObjectId(request_id)
    except Exception as exc:
        raise HTTPException(status_code=400, detail="invalid request_id") from exc

    doc = help_requests_collection.find_one({"_id": object_id})
    if not doc:
        raise HTTPException(status_code=404, detail="help request not found")

    return {
        "request_id": request_id,
        "status": doc.get("status", "OPEN"),
        "category": doc.get("category"),
        "created_at": doc.get("created_at"),
        "updated_at": doc.get("updated_at"),
        "assigned_team_id": doc.get("assigned_team_id"),
    }


@router.get("/pending")
def get_pending_citizen_reports(limit: int = 100, _: dict = Depends(require_authority)):
    docs = list(
        citizen_reports_collection.find(
            {"verified": False},
            {"_id": 1, "zone_id": 1, "type": 1, "level": 1, "filename": 1, "timestamp": 1}
        )
        .sort("timestamp", -1)
        .limit(limit)
    )

    out = []
    for d in docs:
        out.append({
            "report_id": str(d["_id"]),
            "zone_id": d.get("zone_id"),
            "type": d.get("type"),
            "level": d.get("level"),
            "filename": d.get("filename"),
            "filepath": f"/input/citizen/image/{d.get('filename')}" if d.get("filename") else None,
            "timestamp": d.get("timestamp"),
            "verified": False,
        })

    return out


@router.post("/review")
def review_citizen_report(payload: CitizenReviewRequest, _: dict = Depends(require_authority)):
    action = payload.action.strip().upper()
    if action not in {"APPROVE", "REJECT"}:
        return {"status": "error", "message": "action must be APPROVE or REJECT"}

    try:
        object_id = ObjectId(payload.report_id)
    except Exception:
        return {"status": "error", "message": "invalid report_id"}

    result = citizen_reports_collection.update_one(
        {"_id": object_id, "verified": False},
        {
            "$set": {
                "verified": True,
                "review_status": action,
                "verified_by": payload.verifier,
                "verified_at": datetime.now(),
                "review_notes": payload.notes
            }
        }
    )

    if result.matched_count == 0:
        return {"status": "not_found", "report_id": payload.report_id}

    return {
        "status": "reviewed",
        "report_id": payload.report_id,
        "review_status": action,
    }


@router.get("/image/{filename}")
def get_citizen_image(filename: str):
    safe_name = os.path.basename(filename)
    path = UPLOAD_DIR / safe_name

    if not path.exists():
        return {"status": "not_found", "filename": safe_name}

    return FileResponse(path)
