from datetime import datetime
import threading
import traceback
import uuid

from app.ai.dataset_builder import build_dataset
from app.ai.train_cnn import train_cnn
from app.ai.train_lstm import train_lstm
from app.ai.infer import reload_cnn_model
from app.ai.temporal_infer import reload_temporal_model


_state_lock = threading.Lock()
_state = {
    "is_running": False,
    "job": None,
    "history": [],
    "auto_training": {
        "enabled": True,
        "threshold": 50,
        "last_trigger_feedback_total": 0,
    },
}


def _set_running(job):
    with _state_lock:
        _state["is_running"] = True
        _state["job"] = job


def _set_finished(job):
    with _state_lock:
        _state["is_running"] = False
        _state["job"] = job
        _state["history"].insert(0, job.copy())
        _state["history"] = _state["history"][:20]


def get_ml_job_status():
    with _state_lock:
        return {
            "is_running": _state["is_running"],
            "job": _state["job"],
            "history": _state["history"][:10],
            "auto_training": _state["auto_training"].copy(),
        }


def get_auto_training_config():
    with _state_lock:
        return _state["auto_training"].copy()


def set_auto_training_config(*, enabled: bool, threshold: int):
    with _state_lock:
        _state["auto_training"]["enabled"] = enabled
        _state["auto_training"]["threshold"] = max(5, int(threshold))
        return _state["auto_training"].copy()


def start_retrain_and_reload_job(
    *,
    dataset_limit: int = 2000,
    cnn_epochs: int = 5,
    lstm_epochs: int = 10,
):
    with _state_lock:
        if _state["is_running"]:
            return None

    job = {
        "id": str(uuid.uuid4()),
        "status": "RUNNING",
        "step": "initializing",
        "started_at": datetime.now().isoformat(),
        "finished_at": None,
        "error": None,
        "warnings": [],
        "result": {},
    }
    _set_running(job)

    def _runner():
        try:
            job["step"] = "build_dataset"
            copied = build_dataset(limit=dataset_limit)
            job["result"]["dataset_copied"] = copied

            job["step"] = "train_cnn"
            job["result"]["cnn"] = train_cnn(epochs=cnn_epochs)

            job["step"] = "train_lstm"
            lstm_result = train_lstm(epochs=lstm_epochs)
            job["result"]["lstm"] = lstm_result
            if lstm_result.get("skipped"):
                job["warnings"].append(lstm_result.get("reason", "Temporal model training skipped"))

            job["step"] = "hot_reload"
            reload_cnn_model()
            if not lstm_result.get("skipped"):
                reload_temporal_model()

            job["status"] = "SUCCESS_WITH_WARNINGS" if job["warnings"] else "SUCCESS"
            job["step"] = "completed"
        except Exception as exc:
            job["status"] = "FAILED"
            job["step"] = "failed"
            job["error"] = f"{exc}\n{traceback.format_exc()}"
        finally:
            job["finished_at"] = datetime.now().isoformat()
            _set_finished(job)

    thread = threading.Thread(target=_runner, daemon=True, name="ml-retrain-reload")
    thread.start()
    return job


def maybe_trigger_auto_retrain(feedback_total: int):
    with _state_lock:
        auto_cfg = _state["auto_training"].copy()
        if _state["is_running"]:
            return None
        if not auto_cfg["enabled"]:
            return None

        new_feedback = feedback_total - int(auto_cfg["last_trigger_feedback_total"])
        if new_feedback < int(auto_cfg["threshold"]):
            return None

        _state["auto_training"]["last_trigger_feedback_total"] = int(feedback_total)

    # Run a slightly lighter pipeline for automatic retraining.
    return start_retrain_and_reload_job(
        dataset_limit=3000,
        cnn_epochs=4,
        lstm_epochs=8,
    )
