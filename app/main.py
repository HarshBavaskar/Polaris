from fastapi import FastAPI, UploadFile, File, HTTPException
import os
import shutil
import threading
from datetime import datetime
from contextlib import asynccontextmanager
from pathlib import Path


from dotenv import load_dotenv
from fastapi import Depends
from app.auth.jwt_handler import verify_jwt, create_access_token



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
from app.ai.ensemble import compute_ensemble_score, level_from_score
from app.utils.eta_logic import estimate_eta
from app.utils.alert_severity import determine_alert_severity
from app.utils.justification import generate_authority_justification
from app.utils.final_decision import build_final_decision
from app.utils.eta_confidence import determine_eta_confidence
from app.utils.active_learning import (
    feedback_bias,
    should_queue_for_active_learning,
    queue_active_learning_sample,
)
from app.routes.override import router as override_router
from app.database import overrides_collection
from app.routes.camera import router as camera_router
from app.routes.admin_ml import router as admin_ml_router



from app.notifications.valkey_pub import publish_decision
from app.notifications.deliver import deliver
from app.notifications.fcm_push import send_push_fcm_to_targets
from app.notifications.alert_engine import build_alert_payload






# Always resolve .env from repo root so FCM variables load regardless of cwd.
REPO_ROOT = Path(__file__).resolve().parents[1]
load_dotenv(REPO_ROOT / ".env")
from app.routes.map import router as map_router
from app.database import (
    ensure_safezone_indexes,
    ensure_active_learning_indexes,
    ensure_fcm_token_indexes,
)
from app.routes.safezones import router as safezones_router
from app.database import safe_zones_collection, fcm_tokens_collection
from fastapi.middleware.cors import CORSMiddleware
from app.database import historical_events_collection
from app.routes.alerts import router as alerts_router









@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup logic
    ensure_safezone_indexes()
    ensure_active_learning_indexes()
    ensure_fcm_token_indexes()
    retry_stop_event = None
    retry_thread = None
    if ALERT_RETRY_ENABLED:
        retry_stop_event = threading.Event()
        retry_thread = threading.Thread(
            target=_alert_retry_worker,
            args=(retry_stop_event,),
            daemon=True,
            name="alert-retry-worker",
        )
        retry_thread.start()
    app.state.alert_retry_stop_event = retry_stop_event
    app.state.alert_retry_thread = retry_thread
    yield
    # Shutdown logic
    stop_event = getattr(app.state, "alert_retry_stop_event", None)
    thread = getattr(app.state, "alert_retry_thread", None)
    if stop_event is not None:
        stop_event.set()
    if thread is not None and thread.is_alive():
        thread.join(timeout=2)




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
app.include_router(admin_ml_router)





UPLOAD_DIR = "app/uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)


@app.get("/")
def root():
    return {"status": "Polaris server running"}


@app.get("/backend/health")
def backend_health():
    return {
        "up": True,
        "service": "polaris-backend",
        "timestamp": datetime.now()
    }


ALERT_DEDUP_SECONDS = int(os.getenv("ALERT_DEDUP_SECONDS", "180"))
ALERT_RETRY_ENABLED = (os.getenv("ALERT_RETRY_ENABLED", "1").strip() == "1")
ALERT_RETRY_INTERVAL_SECONDS = max(5, int(os.getenv("ALERT_RETRY_INTERVAL_SECONDS", "30")))
ALERT_RETRY_MAX_ATTEMPTS = max(1, int(os.getenv("ALERT_RETRY_MAX_ATTEMPTS", "3")))
ALERT_RETRY_BATCH_SIZE = max(1, int(os.getenv("ALERT_RETRY_BATCH_SIZE", "20")))


def _parse_csv(raw_value: str) -> list[str]:
    if not raw_value:
        return []
    return [item.strip() for item in raw_value.split(",") if item.strip()]


def _mask_token(value: str) -> str:
    if len(value) <= 10:
        return value
    return f"{value[:6]}...{value[-4:]}"


def _resolve_env_path(value: str) -> str:
    expanded = os.path.expanduser(value)
    if os.path.isabs(expanded):
        return expanded
    return str((REPO_ROOT / expanded).resolve())


def _get_fcm_debug_config() -> dict:
    project_id = (os.getenv("FCM_PROJECT_ID") or "").strip()
    service_account_raw = (os.getenv("FCM_SERVICE_ACCOUNT_FILE") or "").strip()
    service_account_path = _resolve_env_path(service_account_raw) if service_account_raw else ""
    service_account_exists = bool(service_account_path and os.path.exists(service_account_path))
    device_tokens = _parse_csv(os.getenv("FCM_DEVICE_TOKENS", ""))
    topic = (os.getenv("FCM_TOPIC") or "").strip()
    registered_tokens_preview = []
    registered_tokens_count = 0
    registered_tokens_error = None
    try:
        registered_tokens = list(
            fcm_tokens_collection.find(
                {"active": True},
                {"_id": 0, "token": 1},
            ).sort("updated_at", -1).limit(3)
        )
        registered_tokens_preview = [
            _mask_token((doc.get("token") or "").strip())
            for doc in registered_tokens
            if (doc.get("token") or "").strip()
        ]
        registered_tokens_count = fcm_tokens_collection.count_documents({"active": True})
    except Exception as exc:
        registered_tokens_error = str(exc)

    issues = []
    if not project_id:
        issues.append("Missing FCM_PROJECT_ID")
    if not service_account_raw:
        issues.append("Missing FCM_SERVICE_ACCOUNT_FILE")
    elif not service_account_exists:
        issues.append(f"Service account file not found: {service_account_path}")
    if not device_tokens and not topic and registered_tokens_count == 0:
        issues.append(
            "No targets configured (set FCM_DEVICE_TOKENS / FCM_TOPIC or register app token)"
        )

    return {
        "provider": "fcm",
        "ready": len(issues) == 0,
        "issues": issues,
        "project_id": project_id or None,
        "service_account_file": service_account_path or None,
        "service_account_file_exists": service_account_exists,
        "device_tokens_count": len(device_tokens),
        "device_tokens_preview": [_mask_token(token) for token in device_tokens[:3]],
        "registered_tokens_count": registered_tokens_count,
        "registered_tokens_preview": registered_tokens_preview,
        "registered_tokens_error": registered_tokens_error,
        "topic": topic or None,
        "dedup_seconds": ALERT_DEDUP_SECONDS,
        "retry_enabled": ALERT_RETRY_ENABLED,
        "retry_interval_seconds": ALERT_RETRY_INTERVAL_SECONDS,
        "retry_max_attempts": ALERT_RETRY_MAX_ATTEMPTS,
        "retry_batch_size": ALERT_RETRY_BATCH_SIZE,
    }


def _retry_failed_alerts_once() -> None:
    if not ALERT_RETRY_ENABLED:
        return

    cursor = alerts_collection.find(
        {
            "status": "failed",
            "retry_count": {"$lt": ALERT_RETRY_MAX_ATTEMPTS},
        }
    ).sort("timestamp", 1).limit(ALERT_RETRY_BATCH_SIZE)

    for alert in cursor:
        payload = {
            "severity": alert.get("severity"),
            "channel": alert.get("channel"),
            "message": alert.get("message"),
            "title": alert.get("title"),
        }

        delivery_result = deliver(payload)
        retry_count = int(alert.get("retry_count", 0)) + 1

        update_doc = {
            "retry_count": retry_count,
            "last_retry_at": datetime.now(),
            "delivery": delivery_result,
        }
        if delivery_result.get("ok"):
            update_doc["status"] = "sent"

        alerts_collection.update_one(
            {"_id": alert["_id"]},
            {"$set": update_doc}
        )


def _alert_retry_worker(stop_event: threading.Event) -> None:
    while not stop_event.is_set():
        try:
            _retry_failed_alerts_once()
        except Exception:
            pass
        stop_event.wait(ALERT_RETRY_INTERVAL_SECONDS)


def _is_recent_duplicate_alert(payload: dict) -> bool:
    if ALERT_DEDUP_SECONDS <= 0:
        return False

    severity = (payload.get("severity") or "").strip().upper()
    message = (payload.get("message") or "").strip()
    if not severity or not message:
        return False

    latest = alerts_collection.find_one(
        {"severity": severity, "message": message},
        sort=[("timestamp", -1)],
        projection={"timestamp": 1},
    )
    if not latest:
        return False

    ts = latest.get("timestamp")
    if not isinstance(ts, datetime):
        return False

    age_seconds = (datetime.now() - ts).total_seconds()
    return age_seconds <= ALERT_DEDUP_SECONDS


def _dispatch_alert_payload(payload: dict, source: str = "API_DISPATCH") -> dict:
    severity = (payload.get("severity") or "").strip().upper()
    channel = (payload.get("channel") or "").strip().upper()
    message = (payload.get("message") or "").strip()

    if not severity or not channel or not message:
        return {
            "status": "failed",
            "channel": channel or payload.get("channel"),
            "severity": severity or payload.get("severity"),
            "delivery": {
                "ok": False,
                "error": "Missing required fields: severity, channel, message",
            },
        }

    normalized_payload = {
        "severity": severity,
        "channel": channel,
        "message": message,
        "title": payload.get("title"),
    }

    if _is_recent_duplicate_alert(normalized_payload):
        duplicate_doc = {
            "channel": channel,
            "severity": severity,
            "message": message,
            "timestamp": datetime.now(),
            "status": "duplicate_ignored",
            "source": source,
            "delivery": {
                "ok": True,
                "provider": "fcm",
                "note": f"Duplicate ignored within {ALERT_DEDUP_SECONDS}s window",
            },
        }
        alerts_collection.insert_one(duplicate_doc)
        return {
            "status": "duplicate_ignored",
            "channel": channel,
            "severity": severity,
            "delivery": {
                "ok": True,
                "provider": "fcm",
                "note": f"Duplicate ignored within {ALERT_DEDUP_SECONDS}s window",
            },
        }

    alert_doc = {
        "channel": channel,
        "severity": severity,
        "message": message,
        "title": normalized_payload.get("title"),
        "timestamp": datetime.now(),
        "status": "queued",
        "source": source,
        "retry_count": 0,
    }

    # store first
    result = alerts_collection.insert_one(alert_doc)

    # deliver
    delivery_result = deliver(normalized_payload)

    # update status
    new_status = "sent" if delivery_result.get("ok") else "failed"
    alerts_collection.update_one(
        {"_id": result.inserted_id},
        {"$set": {"status": new_status, "delivery": delivery_result}}
    )

    return {
        "status": new_status,
        "channel": channel,
        "severity": severity,
        "delivery": delivery_result
    }


@app.post("/backend/start")
def backend_start():
    # This API acknowledges start requests from the dashboard.
    # The process is already running if this endpoint is reachable.
    return {
        "ok": True,
        "started": False,
        "message": "Backend is already running.",
        "timestamp": datetime.now()
    }


@app.post("/input/camera")
async def receive_camera_image(image: UploadFile = File(...)):
    # 1. Save image to disk
    timestamp = datetime.now()
    filename = f"{timestamp.strftime('%Y%m%d_%H%M%S')}_{image.filename}"
    filepath = os.path.join(UPLOAD_DIR, filename)

    with open(filepath, "wb") as buffer:
        shutil.copyfileobj(image.file, buffer)

    # 2. Extract features
    features = extract_features(filepath)

    # 3. Calculate risk
    risk_score = calculate_risk(features)

    recent_risks = get_recent_risks(limit=10)
    recent_risks.append(risk_score)
    spike_detected = is_sudden_spike(recent_risks)

    if spike_detected:
        ai_level = "IMMINENT"
    else:
        ai_level = risk_level(risk_score)


    # Fuse rule-based decision with citizen inputs first.
    fused_rule_level = fuse_risk(ai_level, "TEST_ZONE")

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

    # =========================
    # ENSEMBLE SCORING (rule + cnn + temporal + feedback)
    # =========================
    adaptive_bias = feedback_bias(window=200)
    ensemble_score = compute_ensemble_score(
        rule_risk_score=risk_score,
        cnn_probability=ai_probability,
        temporal_probability=temporal_prob,
        recent_risks=recent_risks,
        feedback_bias=adaptive_bias,
        sudden_spike=spike_detected,
    )
    ensemble_level = level_from_score(ensemble_score)

    # Keep the highest risk suggested by consensus-aware sources.
    LEVEL_ORDER = ["SAFE", "WATCH", "WARNING", "IMMINENT"]
    final_level = max(
        fused_rule_level,
        ai_ml_level,
        temporal_level,
        ensemble_level,
        key=lambda x: LEVEL_ORDER.index(x)
    )

    confidence = calculate_confidence(
        recent_risks=recent_risks,
        ai_level=ai_level,
        final_level=final_level,
        ai_probability=ai_probability,
        temporal_probability=temporal_prob,
        ensemble_score=ensemble_score,
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
    "ensemble_score": ensemble_score,
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
    prediction_result = predictions_collection.insert_one(prediction_doc)

    # Auto-dispatch alerts directly from the decision pipeline.
    # This keeps notifications working even if the external router process is not running.
    auto_alert_payload = build_alert_payload(final_decision)
    if auto_alert_payload:
        _dispatch_alert_payload(auto_alert_payload, source="AUTO_PIPELINE")

    if should_queue_for_active_learning(
        confidence=confidence,
        ensemble_score=ensemble_score,
        cnn_probability=ai_probability,
        temporal_probability=temporal_prob,
    ):
        try:
            queue_active_learning_sample(
                prediction_id=prediction_result.inserted_id,
                image_path=filepath,
                risk_score=risk_score,
                ensemble_score=ensemble_score,
                confidence=confidence,
                cnn_probability=ai_probability,
                temporal_probability=temporal_prob,
                features=features,
            )
        except Exception:
            pass

    return final_decision

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
    source = (payload.get("source") or "API_DISPATCH").strip()
    return _dispatch_alert_payload(payload, source=source)


@app.post("/alert/test-token")
def test_alert_token(payload: dict):
    """
    Sends a test FCM notification to one explicit token.
    Does not use FCM_DEVICE_TOKENS / FCM_TOPIC from .env.
    """
    token = (payload.get("token") or "").strip()
    if not token:
        raise HTTPException(status_code=400, detail="Missing required field: token")

    test_payload = {
        "title": payload.get("title") or "Polaris Test Alert",
        "message": payload.get("message") or "This is a direct token test notification.",
        "severity": (payload.get("severity") or "ADVISORY").upper(),
        "channel": (payload.get("channel") or "APP_NOTIFICATION").upper(),
    }

    delivery_result = send_push_fcm_to_targets(
        test_payload,
        device_tokens=[token],
        topic=None,
    )
    status = "sent" if delivery_result.get("ok") else "failed"

    return {
        "status": status,
        "delivery": delivery_result,
        "payload": test_payload,
    }


@app.post("/alert/register-token")
def register_alert_token(payload: dict):
    token = (payload.get("token") or "").strip()
    if len(token) < 20:
        raise HTTPException(status_code=400, detail="Invalid or missing token")

    platform = (payload.get("platform") or "unknown").strip().lower()
    source = (payload.get("source") or "app_startup").strip()
    user_agent = (payload.get("user_agent") or "").strip()
    now = datetime.now()

    fcm_tokens_collection.update_one(
        {"token": token},
        {
            "$set": {
                "token": token,
                "active": True,
                "platform": platform,
                "source": source,
                "user_agent": user_agent,
                "updated_at": now,
            },
            "$setOnInsert": {"created_at": now},
        },
        upsert=True,
    )

    return {
        "status": "registered",
        "token": _mask_token(token),
        "platform": platform,
        "source": source,
    }


@app.post("/alert/unregister-token")
def unregister_alert_token(payload: dict):
    token = (payload.get("token") or "").strip()
    if len(token) < 20:
        raise HTTPException(status_code=400, detail="Invalid or missing token")

    result = fcm_tokens_collection.update_one(
        {"token": token},
        {"$set": {"active": False, "updated_at": datetime.now()}},
    )

    return {
        "status": "unregistered" if result.matched_count else "not_found",
        "token": _mask_token(token),
    }


@app.get("/alert/debug-status")
def get_alert_debug_status():
    latest_alert = None
    db_error = None
    try:
        latest_alert = alerts_collection.find_one(
            {},
            sort=[("timestamp", -1)],
            projection={"_id": 0},
        )
    except Exception as exc:
        db_error = str(exc)

    return {
        "status": "ok",
        "timestamp": datetime.now(),
        "fcm": _get_fcm_debug_config(),
        "last_alert": latest_alert,
        "last_delivery": (latest_alert or {}).get("delivery"),
        "db_error": db_error,
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

    now = datetime.now()
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

@app.post("/auth/token")
def issue_token():
    """
    Temporary token issuer.
    Later this will be replaced by real user auth.
    """
    token = create_access_token({"role": "authority"})
    return {"access_token": token, "token_type": "bearer"}
