# Polaris Production Checklist

## Secrets and Access

- Rotate any secrets exposed in prior commits, including `.env` values and Firebase-related service credentials.
- Provision fresh values for:
  - `POLARIS_JWT_SECRET`
  - `POLARIS_AUTH_USERNAME`
  - `POLARIS_AUTH_PASSWORD`
  - `POLARIS_INGEST_USERNAME`
  - `POLARIS_INGEST_PASSWORD`
  - `FCM_SERVICE_ACCOUNT_FILE` or `FCM_SERVICE_ACCOUNT_JSON`
- Keep real `.env`, `google-services.json`, and `GoogleService-Info.plist` files out of git and inject them via local setup or CI/CD secrets.
- Prefer `FCM_SERVICE_ACCOUNT_JSON` in Azure App Service application settings to avoid shipping a credential file.

## Backend Configuration

- Set `POLARIS_ENV=production`
- Set `POLARIS_DEBUG=0`
- Set `POLARIS_ENABLE_DEBUG_ENDPOINTS=0`
- Set `POLARIS_ENABLE_TEST_ALERT_ENDPOINTS=0`
- Set `POLARIS_ALLOWED_ORIGINS` to explicit HTTPS origins only
- Set `MONGO_URL` to the production database with auth enabled
- Set `POLARIS_MAX_UPLOAD_BYTES` to the upload ceiling you actually want to enforce
- Set `WEBSITES_PORT=8000` in Azure App Service for the containerized backend

## Infrastructure

- Serve the FastAPI backend behind HTTPS and a real reverse proxy
- Restrict inbound access to MongoDB and Valkey to trusted hosts only
- Enable TLS on public endpoints
- Configure structured logging and external log retention
- Add process supervision and restart policy for the backend and notification workers

## Validation

- Verify `POST /auth/token` works with authority and ingest credentials
- Verify protected endpoints reject unauthenticated access
- Verify dashboard sign-in works and logout returns to the login screen
- Verify `POST /input/camera` succeeds only with ingest/authority auth
- Verify debug/test alert endpoints return 404 in production mode
- Verify both Flutter apps build with locally supplied Firebase config files
- Verify the dashboard web build is generated before running `firebase deploy --only hosting`
- Re-run:
  - `npm audit` in repo root
  - `npm audit` in `polaris_dashboard`
  - `python -m pip_audit -r requirements.txt`

## Hosting Targets

- Deploy the backend container to Azure App Service for Linux.
- Deploy the dashboard web build from `polaris_dashboard/build/web` to Firebase Hosting.
- Use MongoDB Atlas for `MONGO_URL` and allow the Azure backend to reach it.

## Release Hygiene

- Push the rewritten git history before opening new PRs from this branch
- Ask collaborators to re-clone or hard-reset after the history rewrite
- Invalidate any cached artifacts or backups that still contain the removed secret files
