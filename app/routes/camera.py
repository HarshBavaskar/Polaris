import mimetypes
from pathlib import Path

from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse

from app.config import get_settings

router = APIRouter(prefix="/camera", tags=["Camera"])

settings = get_settings()
UPLOAD_DIR = settings.camera_upload_dir

@router.get("/latest-frame")
def get_latest_frame():
    """
    Returns the most recently uploaded camera image
    (used for live dashboard preview)
    """

    if not UPLOAD_DIR.exists():
        raise HTTPException(status_code=404, detail="No camera uploads found")

    files = [
        path
        for path in UPLOAD_DIR.iterdir()
        if path.is_file() and path.suffix.lower() in {".jpg", ".jpeg", ".png", ".webp"}
    ]

    if not files:
        raise HTTPException(status_code=404, detail="No camera images available")

    latest_file = max(files, key=lambda path: path.stat().st_mtime)
    media_type, _ = mimetypes.guess_type(str(Path(latest_file)))

    return FileResponse(latest_file, media_type=media_type or "application/octet-stream")
