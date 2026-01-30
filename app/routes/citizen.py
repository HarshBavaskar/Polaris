from fastapi import APIRouter, UploadFile, File, Form
import os
import shutil
from datetime import datetime

from app.database import citizen_reports_collection

router = APIRouter(prefix="/input/citizen", tags=["Citizen Inputs"])

UPLOAD_DIR = "app/uploads/citizen"
os.makedirs(UPLOAD_DIR, exist_ok=True)


@router.post("/image")
async def citizen_image(
    zone_id: str = Form(...),
    image: UploadFile = File(...)
):
    timestamp = datetime.utcnow()
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
    timestamp = datetime.utcnow()

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
