from __future__ import annotations

import re
from datetime import datetime
from pathlib import Path

from fastapi import HTTPException, UploadFile, status


_ALLOWED_CONTENT_TYPES = {
    "image/jpeg": ".jpg",
    "image/jpg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
}
_FILENAME_SANITIZER = re.compile(r"[^A-Za-z0-9._-]+")


def sanitize_filename(
    raw_filename: str | None,
    *,
    fallback_stem: str = "upload",
    forced_extension: str | None = None,
) -> str:
    original_name = Path(raw_filename or "").name
    suffix = forced_extension or Path(original_name).suffix.lower()
    safe_suffix = suffix if suffix in {".jpg", ".jpeg", ".png", ".webp"} else ""

    stem = Path(original_name).stem
    stem = _FILENAME_SANITIZER.sub("_", stem).strip("._")
    if not stem:
        stem = fallback_stem

    return f"{stem}{safe_suffix}"


async def save_image_upload(
    upload: UploadFile,
    *,
    target_dir: Path,
    max_upload_bytes: int,
) -> tuple[str, str]:
    content_type = (upload.content_type or "").strip().lower()
    if content_type not in _ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail="Only JPEG, PNG, and WEBP image uploads are allowed.",
        )

    target_dir.mkdir(parents=True, exist_ok=True)
    safe_name = sanitize_filename(
        upload.filename,
        forced_extension=_ALLOWED_CONTENT_TYPES[content_type],
    )
    filename = f"{datetime.now().strftime('%Y%m%d_%H%M%S')}_{safe_name}"
    destination = target_dir / filename

    total_bytes = 0
    try:
        with destination.open("wb") as buffer:
            while True:
                chunk = await upload.read(1024 * 1024)
                if not chunk:
                    break
                total_bytes += len(chunk)
                if total_bytes > max_upload_bytes:
                    raise HTTPException(
                        status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                        detail=f"Upload exceeds {max_upload_bytes} bytes.",
                    )
                buffer.write(chunk)
    except HTTPException:
        destination.unlink(missing_ok=True)
        raise
    finally:
        await upload.close()

    return filename, str(destination)
