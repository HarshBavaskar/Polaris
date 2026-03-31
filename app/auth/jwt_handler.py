from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt

from app.config import get_settings


_bearer_scheme = HTTPBearer(auto_error=False)


def create_access_token(data: dict[str, Any], expires_minutes: int | None = None) -> str:
    settings = get_settings()
    issued_at = datetime.now(timezone.utc)
    expire = issued_at + timedelta(
        minutes=expires_minutes or settings.access_token_expire_minutes
    )
    to_encode = data.copy()
    to_encode.update({"iat": issued_at, "exp": expire})
    return jwt.encode(to_encode, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


def authenticate_local_user(username: str, password: str) -> dict[str, str] | None:
    return get_settings().authenticate_local_user(username, password)


def verify_jwt(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer_scheme),
) -> dict[str, Any]:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid Authorization header",
        )

    settings = get_settings()
    try:
        payload = jwt.decode(
            credentials.credentials,
            settings.jwt_secret_key,
            algorithms=[settings.jwt_algorithm],
        )
    except JWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        ) from exc

    role = str(payload.get("role") or "").strip().lower()
    if not role:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token missing required role claim",
        )
    return payload


def require_roles(*roles: str):
    allowed_roles = {role.strip().lower() for role in roles if role.strip()}

    def _dependency(payload: dict[str, Any] = Depends(verify_jwt)) -> dict[str, Any]:
        token_role = str(payload.get("role") or "").strip().lower()
        if allowed_roles and token_role not in allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have permission to access this resource",
            )
        return payload

    return _dependency


require_authority = require_roles("authority")
require_ingest_or_authority = require_roles("authority", "ingest")
