from fastapi import FastAPI, UploadFile, File
import os
import shutil
from datetime import datetime

app = FastAPI(title="Polaris Detection Server")

UPLOAD_DIR = "app/uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

@app.get("/")
def root():
    return {"status": "Polaris server running"}

@app.post("/input/camera")
async def receive_camera_image(image: UploadFile = File(...)):
    timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
    filename = f"{timestamp}_{image.filename}"
    filepath = os.path.join(UPLOAD_DIR, filename)

    with open(filepath, "wb") as buffer:
        shutil.copyfileobj(image.file, buffer)

    return {
        "message": "Image received",
        "filename": filename
    }
