# Polaris Citizen

Citizen-facing Flutter app for emergency reporting, local alert visibility,
safe-zone lookup, and urgent help requests.

## Highlights

- dashboard-aligned Polaris theme and branding
- emergency-first dashboard flow with quick guide animation
- report flooding flow:
  - area+pincode/custom zone modes
  - GPS-assisted area auto-detection
  - flood photo upload and water-level reporting
  - color-coded severity slider
- alerts feed with cache fallback and pull-to-refresh
- safe zones with map, user distance, nearest zone, and ETA
- help request flow with optional live location
- my reports history with status filters (all/synced/pending/failed)
- branded startup loader and Android splash/launcher parity

## Demo

<div align="center">
  <img src="../misc/Polaris Citizen App Demo.gif" width="320"/>
</div>

## API Endpoints Used

- `POST /input/citizen/water-level`
- `POST /input/citizen/image`
- `GET /map/safe-zones`
- `GET /alerts/history`
- `POST /alert/register-token`

## Run

Run:

```bash
cd polaris_citizen
flutter pub get
flutter test
```

Optional run for manual verification:

```bash
flutter run -d chrome --dart-define=POLARIS_API_BASE_URL=http://127.0.0.1:8000
```

Android run (emulator/device):

```bash
flutter devices
flutter run -d <android-device-id> --dart-define=POLARIS_API_BASE_URL=http://<YOUR_LAN_IP>:8000
```

Push notification setup required (one-time):

1. Firebase app config files for `polaris_citizen`:
   - Android: place Firebase `google-services.json` at `polaris_citizen/android/app/google-services.json`
   - iOS: place Firebase `GoogleService-Info.plist` at `polaris_citizen/ios/Runner/GoogleService-Info.plist` and add it to Runner target in Xcode
2. iOS Xcode capability:
   - enable `Push Notifications` for Runner target
3. Backend `.env` must include:
   - `FCM_PROJECT_ID`
   - `FCM_SERVICE_ACCOUNT_FILE`
4. Verify backend config:
   - `GET /alert/debug-status`
5. Send test push:
   - `POST /alert/test-token` with citizen app token
