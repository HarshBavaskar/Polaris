from __future__ import annotations

import os
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

from dotenv import load_dotenv


REPO_ROOT = Path(__file__).resolve().parents[1]
load_dotenv(REPO_ROOT / ".env")

_PLACEHOLDER_SECRETS = {
    "",
    "polaris-secret-key-change-later",
    "polaris-dev-secret-change-me",
    "change-me",
}


def _get_bool(name: str, default: bool) -> bool:
    raw = os.getenv(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


def _get_int(name: str, default: int, *, minimum: int | None = None) -> int:
    raw = os.getenv(name)
    value = default if raw is None else int(raw.strip())
    if minimum is not None:
        value = max(minimum, value)
    return value


def _get_csv(name: str, default: str = "") -> tuple[str, ...]:
    raw = os.getenv(name, default)
    values = [item.strip() for item in raw.split(",") if item.strip()]
    return tuple(values)


@dataclass(frozen=True)
class PolarisSettings:
    environment: str
    debug: bool
    mongo_url: str
    jwt_secret_key: str
    jwt_algorithm: str
    access_token_expire_minutes: int
    allowed_origins: tuple[str, ...]
    max_upload_bytes: int
    camera_upload_dir: Path
    citizen_upload_dir: Path
    enable_debug_endpoints: bool
    enable_test_alert_endpoints: bool
    authority_username: str | None
    authority_password: str | None
    ingest_username: str | None
    ingest_password: str | None

    @property
    def is_production(self) -> bool:
        return self.environment in {"production", "prod"}

    @property
    def cors_allow_all(self) -> bool:
        return len(self.allowed_origins) == 1 and self.allowed_origins[0] == "*"

    def ensure_runtime_directories(self) -> None:
        self.camera_upload_dir.mkdir(parents=True, exist_ok=True)
        self.citizen_upload_dir.mkdir(parents=True, exist_ok=True)

    def validate_startup(self) -> None:
        if not self.is_production:
            return

        problems: list[str] = []
        if self.jwt_secret_key.strip() in _PLACEHOLDER_SECRETS:
            problems.append("POLARIS_JWT_SECRET must be set to a strong secret in production.")
        if not self.allowed_origins or self.cors_allow_all:
            problems.append(
                "POLARIS_ALLOWED_ORIGINS must list explicit HTTPS origins in production."
            )
        if not self.authority_username or not self.authority_password:
            problems.append(
                "POLARIS_AUTH_USERNAME and POLARIS_AUTH_PASSWORD are required in production."
            )
        if self.debug:
            problems.append("POLARIS_DEBUG must be disabled in production.")
        if self.enable_debug_endpoints:
            problems.append("POLARIS_ENABLE_DEBUG_ENDPOINTS must be disabled in production.")
        if self.enable_test_alert_endpoints:
            problems.append(
                "POLARIS_ENABLE_TEST_ALERT_ENDPOINTS must be disabled in production."
            )

        if problems:
            raise RuntimeError("Invalid production configuration:\n- " + "\n- ".join(problems))

    def authenticate_local_user(self, username: str, password: str) -> dict | None:
        normalized_username = username.strip()
        normalized_password = password.strip()
        if not normalized_username or not normalized_password:
            return None

        if (
            self.authority_username
            and self.authority_password
            and normalized_username == self.authority_username
            and normalized_password == self.authority_password
        ):
            return {"sub": normalized_username, "role": "authority"}

        if (
            self.ingest_username
            and self.ingest_password
            and normalized_username == self.ingest_username
            and normalized_password == self.ingest_password
        ):
            return {"sub": normalized_username, "role": "ingest"}

        return None


@lru_cache(maxsize=1)
def get_settings() -> PolarisSettings:
    environment = (os.getenv("POLARIS_ENV") or "development").strip().lower()
    debug_default = environment not in {"production", "prod"}
    allowed_origins_default = "*" if debug_default else ""

    upload_root = (REPO_ROOT / "app" / "uploads").resolve()

    return PolarisSettings(
        environment=environment,
        debug=_get_bool("POLARIS_DEBUG", debug_default),
        mongo_url=(os.getenv("MONGO_URL") or "mongodb://localhost:27017").strip(),
        jwt_secret_key=(os.getenv("POLARIS_JWT_SECRET") or "polaris-dev-secret-change-me").strip(),
        jwt_algorithm=(os.getenv("POLARIS_JWT_ALGORITHM") or "HS256").strip(),
        access_token_expire_minutes=_get_int(
            "POLARIS_ACCESS_TOKEN_EXPIRE_MINUTES",
            60,
            minimum=5,
        ),
        allowed_origins=_get_csv("POLARIS_ALLOWED_ORIGINS", allowed_origins_default),
        max_upload_bytes=_get_int("POLARIS_MAX_UPLOAD_BYTES", 5 * 1024 * 1024, minimum=1024),
        camera_upload_dir=upload_root,
        citizen_upload_dir=upload_root / "citizen",
        enable_debug_endpoints=_get_bool("POLARIS_ENABLE_DEBUG_ENDPOINTS", debug_default),
        enable_test_alert_endpoints=_get_bool(
            "POLARIS_ENABLE_TEST_ALERT_ENDPOINTS",
            debug_default,
        ),
        authority_username=(os.getenv("POLARIS_AUTH_USERNAME") or "").strip() or None,
        authority_password=(os.getenv("POLARIS_AUTH_PASSWORD") or "").strip() or None,
        ingest_username=(os.getenv("POLARIS_INGEST_USERNAME") or "").strip() or None,
        ingest_password=(os.getenv("POLARIS_INGEST_PASSWORD") or "").strip() or None,
    )
