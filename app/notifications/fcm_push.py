import os
from typing import Dict, List
from pathlib import Path
from datetime import datetime

import requests
from dotenv import load_dotenv


FCM_SCOPE = ["https://www.googleapis.com/auth/firebase.messaging"]
REPO_ROOT = Path(__file__).resolve().parents[2]
load_dotenv(REPO_ROOT / ".env")


def _parse_csv(raw_value: str) -> List[str]:
    if not raw_value:
        return []
    return [item.strip() for item in raw_value.split(",") if item.strip()]


def _merge_unique_tokens(*token_groups: List[str]) -> List[str]:
    merged: List[str] = []
    seen = set()
    for group in token_groups:
        for token in group:
            if not token or token in seen:
                continue
            seen.add(token)
            merged.append(token)
    return merged


def _mask_token(value: str) -> str:
    if len(value) <= 10:
        return value
    return f"{value[:6]}...{value[-4:]}"


def _get_access_token(service_account_file: str):
    try:
        from google.auth.transport.requests import Request
        from google.oauth2 import service_account
    except Exception:
        return None, "Missing google-auth dependency. Install with: pip install google-auth"

    try:
        credentials = service_account.Credentials.from_service_account_file(
            service_account_file, scopes=FCM_SCOPE
        )
        credentials.refresh(Request())
        return credentials.token, None
    except Exception as exc:
        return None, f"Failed to load FCM service account: {exc}"


def _is_permanent_token_failure(status_code: int | None, resp_text: str) -> bool:
    text = (resp_text or "").upper()
    if status_code in {400, 403, 404, 410}:
        if (
            "SENDER_ID_MISMATCH" in text
            or "UNREGISTERED" in text
            or "INVALID_ARGUMENT" in text
            or "NOTREGISTERED" in text
            or "REGISTRATION TOKEN IS NOT A VALID FCM REGISTRATION TOKEN" in text
            or "REQUESTED ENTITY WAS NOT FOUND" in text
        ):
            return True
    return False


def _deactivate_stale_tokens(tokens: List[str], reason: str) -> int:
    if not tokens:
        return 0
    try:
        from app.database import fcm_tokens_collection

        result = fcm_tokens_collection.update_many(
            {"token": {"$in": tokens}},
            {
                "$set": {
                    "active": False,
                    "updated_at": datetime.now(),
                    "deactivated_reason": reason,
                }
            },
        )
        return int(result.modified_count or 0)
    except Exception:
        return 0


def send_push_fcm_to_targets(
    payload: Dict,
    device_tokens: List[str] | None = None,
    topic: str | None = None,
) -> Dict:
    """
    Sends push notifications through Firebase Cloud Messaging HTTP v1 API.
    Targets:
    - device_tokens (explicit list)
    - topic (explicit topic)
    """
    project_id = (os.getenv("FCM_PROJECT_ID") or "").strip()
    service_account_file = (os.getenv("FCM_SERVICE_ACCOUNT_FILE") or "").strip()
    service_account_file = os.path.expanduser(service_account_file)
    if service_account_file and not os.path.isabs(service_account_file):
        service_account_file = str((REPO_ROOT / service_account_file).resolve())
    resolved_tokens = [item.strip() for item in (device_tokens or []) if item and item.strip()]
    resolved_topic = (topic or "").strip()

    if not project_id:
        return {
            "ok": False,
            "provider": "fcm",
            "error": "Missing FCM_PROJECT_ID in .env",
        }

    if not service_account_file:
        return {
            "ok": False,
            "provider": "fcm",
            "error": "Missing FCM_SERVICE_ACCOUNT_FILE in .env",
        }

    if not os.path.exists(service_account_file):
        return {
            "ok": False,
            "provider": "fcm",
            "error": f"FCM service account file not found: {service_account_file}",
        }

    if not resolved_tokens and not resolved_topic:
        return {
            "ok": False,
            "provider": "fcm",
            "error": "No FCM targets provided (device token or topic required)",
        }

    access_token, token_error = _get_access_token(service_account_file)
    if token_error:
        return {"ok": False, "provider": "fcm", "error": token_error}

    title = payload.get("title", "Polaris Alert")
    message = payload.get("message", "Alert triggered")
    severity = (payload.get("severity") or "ALERT").upper()
    channel = (payload.get("channel") or "").upper()

    data_payload = {
        "severity": str(severity),
        "channel": str(channel),
        "message": str(message),
    }

    endpoint = f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json; charset=UTF-8",
    }

    targets = [{"kind": "token", "value": token} for token in resolved_tokens]
    if resolved_topic:
        targets.append({"kind": "topic", "value": resolved_topic})

    results = []
    stale_tokens: List[str] = []
    success_count = 0

    for target in targets:
        message_target = {"token": target["value"]} if target["kind"] == "token" else {"topic": target["value"]}
        body = {
            "message": {
                **message_target,
                "notification": {"title": title, "body": message},
                "data": data_payload,
                "android": {"priority": "high"},
                "apns": {"headers": {"apns-priority": "10"}},
            }
        }

        try:
            response = requests.post(endpoint, json=body, headers=headers, timeout=15)
            if 200 <= response.status_code < 300:
                resp_json = response.json()
                success_count += 1
                results.append(
                    {
                        "target": f"{target['kind']}:{_mask_token(target['value'])}",
                        "ok": True,
                        "status_code": response.status_code,
                        "name": resp_json.get("name"),
                    }
                )
            else:
                if target["kind"] == "token" and _is_permanent_token_failure(
                    response.status_code, response.text
                ):
                    stale_tokens.append(target["value"])
                results.append(
                    {
                        "target": f"{target['kind']}:{_mask_token(target['value'])}",
                        "ok": False,
                        "status_code": response.status_code,
                        "resp": response.text,
                    }
                )
        except Exception as exc:
            results.append(
                {
                    "target": f"{target['kind']}:{_mask_token(target['value'])}",
                    "ok": False,
                    "error": str(exc),
                }
            )

    overall_ok = success_count > 0
    deactivated_count = _deactivate_stale_tokens(
        stale_tokens, reason="fcm_permanent_delivery_failure"
    )
    return {
        "ok": overall_ok,
        "provider": "fcm",
        "targets": len(results),
        "delivered_count": success_count,
        "failed_count": len(results) - success_count,
        "deactivated_tokens_count": deactivated_count,
        "results": results,
    }


def send_push_fcm(payload: Dict) -> Dict:
    """
    Sends push notifications through Firebase Cloud Messaging HTTP v1 API.
    Targets from .env:
    - FCM_DEVICE_TOKENS (comma-separated)
    - FCM_TOPIC (optional)
    """
    env_tokens = _parse_csv(os.getenv("FCM_DEVICE_TOKENS", ""))
    include_env_tokens = (os.getenv("FCM_INCLUDE_ENV_TOKENS", "0").strip() == "1")
    topic = (os.getenv("FCM_TOPIC") or "").strip()
    db_tokens: List[str] = []
    db_tokens_error = None
    try:
        from app.database import fcm_tokens_collection

        db_tokens = [
            (doc.get("token") or "").strip()
            for doc in fcm_tokens_collection.find(
                {"active": True},
                {"_id": 0, "token": 1},
            ).limit(1000)
            if (doc.get("token") or "").strip()
        ]
    except Exception as exc:
        db_tokens_error = str(exc)

    token_groups = [db_tokens]
    if include_env_tokens or not db_tokens:
        token_groups.insert(0, env_tokens)
    device_tokens = _merge_unique_tokens(*token_groups)
    result = send_push_fcm_to_targets(
        payload,
        device_tokens=device_tokens,
        topic=topic,
    )
    result["token_sources"] = {
        "env_count": len(env_tokens),
        "env_included": include_env_tokens or not db_tokens,
        "registered_count": len(db_tokens),
        "merged_count": len(device_tokens),
    }
    if db_tokens_error:
        result["token_sources"]["registered_error"] = db_tokens_error
    return result
