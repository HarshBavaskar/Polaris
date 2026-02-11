from fastapi import APIRouter, UploadFile, File, Form
from fastapi.responses import FileResponse
from pydantic import BaseModel, Field
import os
import shutil
from datetime import datetime
from bson import ObjectId

from app.database import citizen_reports_collection

router = APIRouter(prefix="/input/citizen", tags=["Citizen Inputs"])

UPLOAD_DIR = "app/uploads/citizen"
os.makedirs(UPLOAD_DIR, exist_ok=True)


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
    filename = f"{timestamp.strftime('%Y%m%d_%H%M%S')}_{image.filename}"
    filepath = os.path.join(UPLOAD_DIR, filename)

    with open(filepath, "wb") as buffer:
        shutil.copyfileobj(image.file, buffer)

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


@router.get("/pending")
def get_pending_citizen_reports(limit: int = 100):
    docs = list(
        citizen_reports_collection.find(
            {"verified": False},
            {"_id": 1, "zone_id": 1, "type": 1, "level": 1, "filename": 1, "filepath": 1, "timestamp": 1}
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
            "filepath": d.get("filepath"),
            "timestamp": d.get("timestamp"),
            "verified": False,
        })

    return out


@router.post("/review")
def review_citizen_report(payload: CitizenReviewRequest):
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
    path = os.path.join(UPLOAD_DIR, safe_name)

    if not os.path.exists(path):
        return {"status": "not_found", "filename": safe_name}

    return FileResponse(path)
