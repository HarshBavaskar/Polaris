from fastapi import FastAPI, UploadFile, File
import os
import shutil
from datetime import datetime

from app.utils.image_processing import extract_features
from app.utils.risk_logic import calculate_risk, risk_level
from app.database import images_collection, predictions_collection
from app.utils.time_series import get_recent_risks, is_sudden_spike
from app.routes.citizen import router as citizen_router
from app.utils.fusion_logic import fuse_risk
from app.routes.feedback import router as feedback_router
from app.utils.confidence_logic import calculate_confidence
from app.routes.dashboard import router as dashboard_router






app = FastAPI(title="Polaris Detection Server")
app.include_router(citizen_router)
app.include_router(feedback_router)
app.include_router(dashboard_router)



UPLOAD_DIR = "app/uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)


@app.get("/")
def root():
    return {"status": "Polaris server running"}


@app.post("/input/camera")
async def receive_camera_image(image: UploadFile = File(...)):
    # 1. Save image to disk
    timestamp = datetime.utcnow()
    filename = f"{timestamp.strftime('%Y%m%d_%H%M%S')}_{image.filename}"
    filepath = os.path.join(UPLOAD_DIR, filename)

    with open(filepath, "wb") as buffer:
        shutil.copyfileobj(image.file, buffer)

    # 2. Extract features
    features = extract_features(filepath)

    # 3. Calculate risk
    risk_score = calculate_risk(features)

    recent_risks = get_recent_risks(limit=5)
    recent_risks.append(risk_score)

    if is_sudden_spike(recent_risks):
        ai_level = "IMMINENT"
    else:
        ai_level = risk_level(risk_score)

    #FUSE WITH CITIZEN INPUTS
    final_level = fuse_risk(ai_level, "TEST_ZONE")
    confidence = calculate_confidence(
    recent_risks=recent_risks,
    ai_level=ai_level,
    final_level=final_level
)



    # 4. Save image metadata
    image_doc = {
        "filename": filename,
        "filepath": filepath,
        "timestamp": timestamp
    }
    image_result = images_collection.insert_one(image_doc)

    # 5. Save prediction
    prediction_doc = {
        "image_id": image_result.inserted_id,
        "features": features,
        "risk_score": risk_score,
        "risk_level": final_level,
        "confidence": confidence,
        "ai_level": ai_level,
        "timestamp": timestamp
    }
    predictions_collection.insert_one(prediction_doc)

    # 6. Return response
    return {
    "message": "Image processed & stored",
    "filename": filename,
    "features": features,
    "risk_score": risk_score,
    "ai_level": ai_level,
    "risk_level": final_level,
    "confidence": confidence,
    "recent_risks": recent_risks
}

