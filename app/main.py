from fastapi import FastAPI, UploadFile, File
import os
import shutil
from datetime import datetime, timezone
from contextlib import asynccontextmanager





from app.utils.image_processing import extract_features
from app.utils.risk_logic import calculate_risk, risk_level
from app.database import images_collection, predictions_collection, alerts_collection
from app.utils.time_series import get_recent_risks, is_sudden_spike
from app.routes.citizen import router as citizen_router
from app.utils.fusion_logic import fuse_risk
from app.routes.feedback import router as feedback_router
from app.utils.confidence_logic import calculate_confidence
from app.routes.dashboard import router as dashboard_router
from app.ai.infer import ai_predict
from app.ai.temporal_infer import temporal_predict
from app.utils.eta_logic import estimate_eta
from app.utils.alert_severity import determine_alert_severity
from app.utils.justification import generate_authority_justification
from app.utils.final_decision import build_final_decision
from app.utils.eta_confidence import determine_eta_confidence
from app.routes.override import router as override_router
from app.database import overrides_collection
from app.routes.camera import router as camera_router



from app.notifications.valkey_pub import publish_decision
from app.notifications.deliver import deliver








app = FastAPI(title="Polaris Detection Server")
from app.routes.map import router as map_router
from app.database import ensure_safezone_indexes
from app.routes.safezones import router as safezones_router
from app.database import safe_zones_collection
from fastapi.middleware.cors import CORSMiddleware
from app.database import historical_events_collection
from app.routes.alerts import router as alerts_router









@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup logic
    ensure_safezone_indexes()
    yield
    # Shutdown logic (optional, none needed now)




app = FastAPI(title="Polaris Detection Server", lifespan=lifespan )
app.include_router(citizen_router)
app.include_router(feedback_router)
app.include_router(dashboard_router)
app.include_router(override_router)
app.include_router(map_router)
app.include_router(safezones_router)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # OK for development
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(alerts_router)
app.include_router(camera_router)





UPLOAD_DIR = "app/uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)


@app.get("/")
def root():
    return {"status": "Polaris server running"}


@app.post("/input/camera")
async def receive_camera_image(image: UploadFile = File(...)):
    # 1. Save image to disk
    timestamp = datetime.now(timezone.utc)
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

    # =========================
    # AI MODEL (CNN) PREDICTION
    # =========================
    ai_probability = ai_predict(filepath)

    if ai_probability > 0.7:
        ai_ml_level = "IMMINENT"
    elif ai_probability > 0.5:
        ai_ml_level = "WARNING"
    else:
        ai_ml_level = "SAFE"

    # =========================
    # SAFE FUSION (NEVER DOWNGRADE) CNN BASED
    # =========================
    LEVEL_ORDER = ["SAFE", "WATCH", "WARNING", "IMMINENT"]

    final_level = max(
    final_level,
    ai_ml_level,
    key=lambda x: LEVEL_ORDER.index(x)
    )
    confidence = calculate_confidence(
    recent_risks=recent_risks,
    ai_level=ai_level,
    final_level=final_level
    )       
    # =========================
    # TEMPORAL AI (SEQUENCE)
    # =========================
    recent_sequence = []

    for r in recent_risks[-10:]:
        recent_sequence.append([
        ai_probability,
        risk_score,
        features["brightness"],
        features["edge_density"],
        features["entropy"]
        ])

    if len(recent_sequence) == 10:
        temporal_prob = temporal_predict(recent_sequence)
    else:
        temporal_prob = 0.0

    if temporal_prob > 0.7:
        temporal_level = "IMMINENT"
    elif temporal_prob > 0.5:
        temporal_level = "WARNING"
    else:
        temporal_level = "SAFE"

    final_level = max(
        final_level,
        temporal_level,
        key=lambda x: LEVEL_ORDER.index(x)
    )


    #ETA Calculation
    eta = estimate_eta(
    recent_risks=recent_risks,
    temporal_probability=temporal_prob
    )

    eta_confidence = determine_eta_confidence(
    recent_risks=recent_risks,
    temporal_probability=temporal_prob,
    confidence=confidence
    )


    # Determine alert severity
    alert_severity = determine_alert_severity(
        risk_level=final_level,
        confidence=confidence,
        eta=eta,
        eta_confidence=eta_confidence,
        temporal_probability=temporal_prob
    )


    # Generate authority justification
    authority_justification = generate_authority_justification(
    risk_level=final_level,
    confidence=confidence,
    eta=eta,
    eta_confidence=eta_confidence,
    ai_probability=ai_probability,
    temporal_probability=temporal_prob
    )


    final_decision = build_final_decision(
    risk_level=final_level,
    confidence=confidence,
    eta=eta,
    eta_confidence=eta_confidence,
    alert_severity=alert_severity,
    justification=authority_justification
)
    publish_decision(final_decision)



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
    "timestamp": timestamp,

    # Core outcomes
    "risk_score": risk_score,
    "risk_level": final_level,
    "confidence": confidence,

    # AI outputs (learning-critical)
    "ai_probability": ai_probability,
    "ai_ml_level": ai_ml_level,
    "temporal_probability": temporal_prob,
    "temporal_level": temporal_level,

    # Features (for retraining & explainability)
    "features": features,
    "eta": eta,
    "alert_severity": alert_severity,
    "authority_justification": authority_justification,
    "eta_confidence": eta_confidence
}
    prediction_doc["final_decision"] = final_decision
    predictions_collection.insert_one(prediction_doc)

    return final_decision

    # 6. Return response
    return {
    "message": "Image processed & stored",
    "filename": filename,
    "features": features,
    "risk_score": risk_score,
    "ai_level": ai_level,          # rule-based
    "ai_ml_level": ai_ml_level,    # CNN-based
    "ai_probability": ai_probability,
    "risk_level": final_level,
    "confidence": confidence,
    "recent_risks": recent_risks,
    "temporal_probability": temporal_prob,
    "temporal_level": temporal_level,
    "estimated_time_to_cloudburst": eta,
    "eta_confidence": eta_confidence,
    "alert_severity": alert_severity,
    "authority_justification": authority_justification
    }

@app.get("/decision/latest")
def get_latest_decision():
    # 1️⃣ Check override FIRST
    override = overrides_collection.find_one(
        {"active": True},
        sort=[("timestamp", -1)]
    )

    if override:
        return {
            "final_risk_level": override["risk_level"],
            "final_confidence": 1.0,
            "final_eta": "UNKNOWN",
            "final_eta_confidence": "HIGH",
            "final_alert_severity": override["alert_severity"],
            "decision_mode": "MANUAL_OVERRIDE",
            "justification": f"Manual override by {override['author']}: {override['reason']}",
        }

    # 2️⃣ Otherwise return last AI decision
    doc = predictions_collection.find_one({}, sort=[("timestamp", -1)])

    if not doc:
        return {"message": "No decisions yet"}

    return doc.get("final_decision", {"message": "Final decision not stored yet"})




@app.post("/alert/dispatch")
def dispatch_alert(payload: dict):
    alert_doc = {
        "channel": payload.get("channel"),
        "severity": payload.get("severity"),
        "message": payload.get("message"),
        "timestamp": datetime.now(timezone.utc),
        "status": "queued"
    }

    # 1. Store alert first (always)
    result = alerts_collection.insert_one(alert_doc)

    # 2. Try delivering alert (SMS / simulated / future push)
    delivery_result = deliver(payload)

    # 3. Update delivery status
    new_status = "sent" if delivery_result.get("ok") else "failed"

    alerts_collection.update_one(
        {"_id": result.inserted_id},
        {
            "$set": {
                "status": new_status,
                "delivery": delivery_result
            }
        }
    )

    # 4. Return response
    return {
        "status": new_status,
        "channel": payload.get("channel"),
        "severity": payload.get("severity"),
        "delivery": delivery_result
    }

@app.get("/alerts/latest")
def get_latest_alerts(limit: int = 20):
    alerts = list(
        alerts_collection.find({}, {"_id": 0})
        .sort("timestamp", -1)
        .limit(limit)
    )
    return alerts

@app.get("/predictions/history")
def get_prediction_history(hours: int = 24):
    from datetime import timedelta

    now = datetime.now(timezone.utc)
    since = now - timedelta(hours=hours)

    preds = list(
        predictions_collection.find(
            {"timestamp": {"$gte": since}},
            {
                "_id": 0,
                "timestamp": 1,
                "risk_score": 1,
                "confidence": 1,
                "alert_severity": 1,
            }
        ).sort("timestamp", 1)
    )

    return preds

@app.get("/map/live-risk")
def get_live_risk_points(limit: int = 50):
    points = list(
        predictions_collection.find(
            {},
            {
                "_id": 0,
                "timestamp": 1,
                "risk_score": 1,
                "risk_level": 1,
                "alert_severity": 1,
            }
        )
        .sort("timestamp", -1)
        .limit(limit)
    )

    # TEMP: fixed location (replace later with camera metadata)
    for p in points:
        p["lat"] = 19.0760   # Mumbai
        p["lng"] = 72.8777

    return points

@app.get("/map/safe-zones")
def get_safe_zones():
    zones = list(
        safe_zones_collection.find({}, {"_id": 0})
    )
    return zones



@app.get("/map/historical-events")
def get_historical_events():
    events = list(
        historical_events_collection.find({}, {"_id": 0})
    )
    return events

