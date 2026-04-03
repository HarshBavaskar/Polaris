# Polaris Dashboard

Authority-facing Flutter dashboard for real-time risk monitoring, map intelligence,
alert operations, and override control in the Polaris system.

## Highlights

- live operational overview with risk, confidence, and ETA trends
- active alert timeline and control surfaces
- citizen verification workflow integration
- map overlays for risk, safe zones, and historical events
- Android-optimized compact UI mode and branded Polaris shell
- FCM web/app notification integration

## Demo

<div align="center">
  <img src="../misc/Polaris Dashboard Demo.gif" width="760"/>
</div>

## Run

```bash
cd polaris_dashboard
flutter pub get
flutter run -d chrome --dart-define=POLARIS_API_BASE_URL=http://127.0.0.1:8000
```

The dashboard now starts on an authority sign-in screen.
You can type credentials there, or prefill them with:
`--dart-define=POLARIS_AUTH_USERNAME=<authority-user>`
`--dart-define=POLARIS_AUTH_PASSWORD=<authority-password>`

## Optional Android Run

```bash
flutter devices
flutter run -d <android-device-id> \
  --dart-define=POLARIS_API_BASE_URL=http://<YOUR_LAN_IP>:8000
```

## Firebase Android Config

- Keep the real Firebase Android client config at `polaris_dashboard/android/app/google-services.json`.
- Use `polaris_dashboard/android/app/google-services.example.json` as a placeholder reference only.
- The real file is intentionally gitignored and must come from local setup or CI secrets.

## Web Hosting Build

Build the dashboard for Firebase Hosting with the live backend URL:

```bash
cd polaris_dashboard
flutter pub get
flutter build web --dart-define=POLARIS_API_BASE_URL=https://<your-backend>.azurewebsites.net
```

Then deploy from the repo root:

```bash
firebase deploy --only hosting
```
