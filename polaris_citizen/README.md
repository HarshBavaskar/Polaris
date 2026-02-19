# Polaris Citizen (Phase 6)

Small first slice of the citizen app in a separate folder.

Included now:

- basic Flutter app shell
- citizen-only bottom tabs:
  - Dashboard
  - Report Flooding (implemented)
  - Safe Zones (implemented)
- report API wiring:
  - `POST /input/citizen/water-level`
  - `POST /input/citizen/image`
- meaningful zone selection in report flow:
  - auto-load suggested zone IDs from active safe zones
  - dropdown select by default
  - area + pincode mode (city/locality/pincode -> generated zone ID)
  - optional custom zone override when needed
  - GPS-assisted nearest safe-zone selection
- safe-zones API wiring:
  - `GET /map/safe-zones`
- widget and unit tests for shell + report flow
  - safe-zones API and screen states
- citizen home dashboard:
  - quick actions to open Report and Safe Zones tabs
  - live safe-zone count snapshot
  - reporting and safety guidance cards
- mobile platform permissions:
  - Android `INTERNET`, `CAMERA`
  - iOS `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`

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
