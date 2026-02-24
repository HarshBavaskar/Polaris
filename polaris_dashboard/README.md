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

## Optional Android Run

```bash
flutter devices
flutter run -d <android-device-id> --dart-define=POLARIS_API_BASE_URL=http://<YOUR_LAN_IP>:8000
```
