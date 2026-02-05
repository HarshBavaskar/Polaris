from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse
import os

router = APIRouter(prefix="/camera", tags=["Camera"])

UPLOAD_DIR = "app/uploads"

@router.get("/latest-frame")
def get_latest_frame():
    """
    Returns the most recently uploaded camera image
    (used for live dashboard preview)
    """

    if not os.path.exists(UPLOAD_DIR):
        raise HTTPException(status_code=404, detail="No camera uploads found")

    files = [
        os.path.join(UPLOAD_DIR, f)
        for f in os.listdir(UPLOAD_DIR)
        if f.lower().endswith((".jpg", ".jpeg", ".png"))
    ]

    if not files:
        raise HTTPException(status_code=404, detail="No camera images available")

    latest_file = max(files, key=os.path.getmtime)

    return FileResponse(latest_file, media_type="image/jpeg")
