# Polaris Backend Deployment

## Render

This repo now includes a root `render.yaml` so Render can run the backend with its native Python runtime instead of Docker.

### Service setup

1. Push this repo with `render.yaml` at the root.
2. In Render, create a new Blueprint or Web Service from the repository.
3. Keep the service root at the repo root `/`.
4. Render should use the Python runtime with:
   - build command: `pip install --upgrade pip && pip install -r requirements.txt`
   - start command: `uvicorn app.main:app --host 0.0.0.0 --port $PORT`

### Required environment variables

Render prompts for variables marked `sync: false` in `render.yaml` when you create the service.

Required:

- `POLARIS_ALLOWED_ORIGINS=https://<your-dashboard-domain>`
- `MONGO_URL=<your-mongodb-atlas-uri>`
- `POLARIS_AUTH_USERNAME=<authority-username>`
- `POLARIS_AUTH_PASSWORD=<authority-password>`
- `POLARIS_INGEST_USERNAME=<ingest-username>`
- `POLARIS_INGEST_PASSWORD=<ingest-password>`
- `FCM_PROJECT_ID=<firebase-project-id>`
- `FCM_SERVICE_ACCOUNT_JSON=<firebase-admin-json>`

Generated automatically:

- `POLARIS_JWT_SECRET`

Defaults provided by the Blueprint:

- `POLARIS_ENV=production`
- `POLARIS_DEBUG=0`
- `POLARIS_ENABLE_DEBUG_ENDPOINTS=0`
- `POLARIS_ENABLE_TEST_ALERT_ENDPOINTS=0`
- `POLARIS_MAX_UPLOAD_BYTES=5242880`
- `POLARIS_UPLOAD_ROOT=/tmp/polaris/uploads`
- `ALERT_RETRY_ENABLED=0`

### Health check

After deploy, verify:

```bash
curl https://<your-render-service>.onrender.com/backend/health
```

### Free plan caveats

- Render Free spins the service down after 15 minutes of idle time.
- Free web services have an ephemeral filesystem, so uploaded files are lost on restart, redeploy, or spin-down.
- Free web services cannot attach persistent disks.
- Render documents that Free services may be suspended for unusually high service-initiated public internet traffic, including external database access.

If you upgrade to a paid Render plan later, set `POLARIS_UPLOAD_ROOT` to a mounted persistent disk path.

### Common Render failure modes for this repo

- Missing `MONGO_URL`, causing startup to fail during database ping.
- Missing production auth variables, causing startup validation to fail.
- Missing `FCM_SERVICE_ACCOUNT_JSON` or `FCM_SERVICE_ACCOUNT_FILE`.
- `POLARIS_ALLOWED_ORIGINS` left as `*`, which is rejected in production mode.
- Expecting uploaded files to survive restarts on the Free plan.
