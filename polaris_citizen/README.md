# Polaris Citizen (Phase 9)

Small first slice of the citizen app in a separate folder.

Included now:

- basic Flutter app shell
- citizen-only app navigation (drawer):
  - Dashboard
  - Alerts (implemented)
  - Report Flooding (implemented)
  - Safe Zones (implemented)
  - My Reports (implemented)
- report API wiring:
  - `POST /input/citizen/water-level`
  - `POST /input/citizen/image`
- meaningful zone selection in report flow:
  - area + pincode mode (Mumbai/Thane/Navi Mumbai/Palghar focus for now)
  - optional custom zone override when needed
  - GPS-assisted auto area detection from user location
- safe-zones API wiring:
  - `GET /map/safe-zones`
  - safe zone cards now include:
    - area and pincode (from backend if available; focused fallback inference for Mumbai/Thane/Navi Mumbai/Palghar)
    - distance in km from citizen location
    - "updated X ago" from `last_verified`
- widget and unit tests for shell + report flow
  - alerts API/screen/cache
  - my reports history
  - safe-zones API and screen states
- citizen home dashboard:
  - quick actions to open Report and Safe Zones tabs
  - live safe-zone count snapshot
  - reporting and safety guidance cards
  - emergency helpline section with quick-call actions
  - area dropdown for district-wise helpline guidance
  - optional live-location helper for emergency sharing
- mobile platform permissions:
  - Android `INTERNET`, `CAMERA`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`
  - iOS `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSLocationWhenInUseUsageDescription`
- push notification flow (FCM):
  - app requests notification permission on startup (Android/iOS)
  - app fetches FCM token and registers it to backend `POST /alert/register-token`
  - app listens for foreground/background push
  - tapping notification opens Alerts tab directly in citizen app

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
