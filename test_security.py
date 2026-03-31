import unittest
from pathlib import Path

from fastapi import HTTPException

from app.auth.jwt_handler import require_roles
from app.config import PolarisSettings
from app.upload_security import sanitize_filename


def _settings(**overrides):
    base = {
        "environment": "development",
        "debug": True,
        "mongo_url": "mongodb://localhost:27017",
        "jwt_secret_key": "dev-secret-not-for-prod",
        "jwt_algorithm": "HS256",
        "access_token_expire_minutes": 60,
        "allowed_origins": ("*",),
        "max_upload_bytes": 1024 * 1024,
        "camera_upload_dir": Path("app/uploads"),
        "citizen_upload_dir": Path("app/uploads/citizen"),
        "enable_debug_endpoints": True,
        "enable_test_alert_endpoints": True,
        "authority_username": "authority",
        "authority_password": "authority-password",
        "ingest_username": "ingest",
        "ingest_password": "ingest-password",
    }
    base.update(overrides)
    return PolarisSettings(**base)


class SecurityHardeningTests(unittest.TestCase):
    def test_sanitize_filename_removes_path_traversal(self):
        sanitized = sanitize_filename(r"..\..\bad file!!.png")
        self.assertEqual(sanitized, "bad_file.png")

    def test_production_settings_reject_insecure_defaults(self):
        settings = _settings(
            environment="production",
            debug=True,
            jwt_secret_key="polaris-secret-key-change-later",
            allowed_origins=("*",),
            enable_debug_endpoints=True,
            enable_test_alert_endpoints=True,
        )

        with self.assertRaises(RuntimeError):
            settings.validate_startup()

    def test_local_user_authentication_supports_authority_and_ingest(self):
        settings = _settings()

        self.assertEqual(
            settings.authenticate_local_user("authority", "authority-password"),
            {"sub": "authority", "role": "authority"},
        )
        self.assertEqual(
            settings.authenticate_local_user("ingest", "ingest-password"),
            {"sub": "ingest", "role": "ingest"},
        )
        self.assertIsNone(settings.authenticate_local_user("bad", "creds"))

    def test_require_roles_allows_matching_role(self):
        dependency = require_roles("authority")
        payload = dependency({"role": "authority"})
        self.assertEqual(payload["role"], "authority")

    def test_require_roles_blocks_wrong_role(self):
        dependency = require_roles("authority")
        with self.assertRaises(HTTPException) as ctx:
            dependency({"role": "ingest"})
        self.assertEqual(ctx.exception.status_code, 403)


if __name__ == "__main__":
    unittest.main()
