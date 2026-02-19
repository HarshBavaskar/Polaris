# Polaris Citizen (Phase 2)

Small first slice of the citizen app in a separate folder.

Included now:

- basic Flutter app shell
- citizen-only bottom tabs:
  - Dashboard
  - Report Flooding (implemented)
  - Safe Zones (placeholder)
- report API wiring:
  - `POST /input/citizen/water-level`
  - `POST /input/citizen/image`
- widget and unit tests for shell + report flow

Run:

```bash
cd polaris_citizen
flutter pub get
flutter test
```
