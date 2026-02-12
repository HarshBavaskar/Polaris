from fastapi import APIRouter

from app.services.ml_admin_service import (
    start_retrain_and_reload_job,
    get_ml_job_status,
    get_auto_training_config,
    set_auto_training_config,
)

router = APIRouter(prefix="/admin/ml", tags=["Admin ML"])


@router.post("/retrain-and-reload")
def retrain_and_reload(
    dataset_limit: int = 2000,
    cnn_epochs: int = 5,
    lstm_epochs: int = 10,
):
    """
    One-click admin pipeline:
    1) Build dataset from latest predictions/feedback
    2) Retrain CNN + temporal model
    3) Hot reload both models into the running backend
    """
    job = start_retrain_and_reload_job(
        dataset_limit=dataset_limit,
        cnn_epochs=cnn_epochs,
        lstm_epochs=lstm_epochs,
    )
    if job is None:
        return {
            "ok": False,
            "message": "A retrain job is already running.",
            "status": get_ml_job_status(),
        }

    return {
        "ok": True,
        "message": "Retrain-and-reload job started in background.",
        "job": job,
    }


@router.get("/status")
def retrain_status():
    return get_ml_job_status()


@router.get("/auto-config")
def get_auto_config():
    return get_auto_training_config()


@router.post("/auto-config")
def update_auto_config(
    enabled: bool = True,
    threshold: int = 50,
):
    cfg = set_auto_training_config(enabled=enabled, threshold=threshold)
    return {
        "ok": True,
        "auto_training": cfg,
    }
