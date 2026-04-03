# Polaris Deployment

This repo is set up to deploy:

- backend -> Azure App Service for Linux using a custom container
- dashboard web app -> Firebase Hosting
- database -> MongoDB Atlas `M0`

## 1. Backend container

Build the backend image from the repo root:

```bash
docker build -t polaris-backend:latest .
```

Run it locally with production-like settings:

```bash
docker run --rm -p 8000:8000 --env-file .env polaris-backend:latest
```

The container listens on port `8000`. In Azure App Service, set:

```text
WEBSITES_PORT=8000
```

## 2. Azure App Service settings

Use `AZURE_APP_SERVICE_SETTINGS.example` as the template for App Service application settings.

Recommended secret strategy for FCM:

- Set `FCM_SERVICE_ACCOUNT_JSON` directly in App Service settings.
- Leave `FCM_SERVICE_ACCOUNT_FILE` empty unless you explicitly mount a file.

Required production values:

- `POLARIS_ENV=production`
- `POLARIS_DEBUG=0`
- `POLARIS_ENABLE_DEBUG_ENDPOINTS=0`
- `POLARIS_ENABLE_TEST_ALERT_ENDPOINTS=0`
- `POLARIS_ALLOWED_ORIGINS=https://<site>.web.app,https://<site>.firebaseapp.com`
- `MONGO_URL=<MongoDB Atlas URI>`
- `WEBSITES_PORT=8000`

## 3. MongoDB Atlas

Create a free Atlas cluster and database user, then set:

```text
MONGO_URL=mongodb+srv://<username>:<password>@<cluster>/polaris?retryWrites=true&w=majority
```

Allow the Azure backend to connect using Atlas network access rules.

## 4. Dashboard build

Build the hosted dashboard with the live backend URL:

```bash
cd polaris_dashboard
flutter pub get
flutter build web --dart-define=POLARIS_API_BASE_URL=https://<your-backend>.azurewebsites.net
```

Firebase Hosting now serves `polaris_dashboard/build/web`, including the root-level
`firebase-messaging-sw.js` file required by the dashboard web push setup.

## 5. Firebase Hosting deploy

From the repo root:

```bash
firebase deploy --only hosting
```

Firebase Hosting will deploy to:

- `https://<project-id>.web.app`
- `https://<project-id>.firebaseapp.com`

## 6. Validation

After backend deployment:

```bash
curl https://<your-backend>.azurewebsites.net/backend/health
```

After dashboard deployment:

- open the Firebase Hosting URL
- verify sign-in works
- verify protected actions still require auth
- verify public data panels load
- verify `/firebase-messaging-sw.js` is reachable
