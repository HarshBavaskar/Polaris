<div align="center">

<img src="misc/Polaris_Logo_Side.PNG" height="250"/>

| **Current Version** | `v0.9: Stable Notifications, Web Push Stabilization, and Android Dashboard Revamp` |
| --- | --- |

</div>

---

> **An AI-powered, real-time, hyperlocal cloudburst early warning and decision system**  
> combining **computer vision**, **temporal intelligence**, and **human-in-the-loop authority**.

---

## Overview

**Polaris** is a research-grade early warning and decision platform designed to detect cloudburst-like risk before severe impact.
It combines:

- vision features from camera inputs
- temporal escalation modeling
- citizen-ground reports
- rule-based safety checks
- authority override controls

The result is a safety-first, explainable system built for operational decision support.

---

## Latest Branch Updates (v0.9)

The README now reflects the latest commit series on this branch:

| Commit | Summary |
| --- | --- |
| `f5702c8` | Notification reliability upgrades, web push stabilization, Android UI/branding revamp |
| `a80a954` | Failed-alert retry worker and retry configuration support |
| `542a153` | Firebase Cloud Messaging (web + app), service worker and token flow integration |
| `eb5de51` | Firebase hosting configuration and deployment workflow scaffolding |
| `13251b8` | Removed Firebase service account JSON from version control |

### v0.9 Highlights

#### Notification Reliability

- FCM delivery now treats dispatch as success when at least one target succeeds.
- Permanent token failures are auto-deactivated in token storage.
- Delivery responses include `delivered_count`, `failed_count`, and `deactivated_tokens_count`.
- Dedup logic suppresses repeated alerts within `ALERT_DEDUP_SECONDS`.
- Failed alerts can be retried automatically by a background worker (`ALERT_RETRY_*` settings).

#### Web Push Stabilization

- Service worker readiness is enforced before requesting web FCM tokens.
- Web foreground duplicate popups are avoided by design.
- Service worker logic avoids duplicate manual notifications for notification payloads.
- Token registration diagnostics were improved for non-2xx backend responses.

#### Android Dashboard Revamp

- Compact navigation flow was refined for smoother mobile operations.
- Screen switching now uses `IndexedStack` for state-preserving transitions.
- Polaris branding/icons were refreshed for Android launcher and app shell.
- Foreground local notifications are enabled through `flutter_local_notifications`.

#### Deployment and Tooling

- Firebase hosting config files were added (`firebase.json`, `.firebaserc`, workflows).
- Notification-path verification and phone-proxy tooling were introduced for reliability testing.

---

## Dashboard UI

<div align="center">
  <img src="misc/Polaris Dashboard Demo.gif"/>
</div>

---

## System Architecture

```text
Camera / Images
  -> Image Feature Extraction (brightness, entropy, edges)
  -> Rule-Based Risk Logic
  -> Time-Series Spike Detection
  -> CNN (spatial model)
  -> LSTM (temporal model)
  -> Citizen Input Fusion
  -> Safety-First Final Decision (with authority override support)
  -> Auto Alert Dispatch (FCM)
  -> MongoDB + Dashboard / Map APIs
```

---

## Key Capabilities

### Vision and Temporal Intelligence

- CNN-based visual pattern detection for high-risk sky conditions
- LSTM-based temporal escalation detection
- Ensemble scoring with rule + CNN + temporal + trend + feedback signals

### Human-in-the-Loop Controls

- authority override with auditable metadata
- citizen image and water-level inputs
- authority feedback ingestion for model improvement

### Active Learning and ML Admin Controls

- uncertain sample queue and labeling-aware loop
- admin retrain-and-reload pipeline
- auto-training configuration controls

### Dashboard and Map Experience

- live status, risk, confidence, and ETA trends
- map overlays for live risk, safe zones, and historical events
- mobile-friendly UI updates for compact Android usage

---

## Notification and Alert Routing (v0.9)

- Alert dispatch is handled through **Firebase Cloud Messaging (FCM)** only.
- Auto-dispatch is triggered directly from the decision pipeline in `app/main.py`.
- Valkey publication remains available for compatibility workflows.
- Manual override remains authoritative over automated decisions.

### Supported Dispatch Channels

- `APP_NOTIFICATION`
- `PUSH_NOTIFICATION`
- `PUSH_SMS`
- `SMS_SIREN`
- `ALL_CHANNELS`

### Required Environment Variables

- `FCM_PROJECT_ID`
- `FCM_SERVICE_ACCOUNT_FILE` (absolute or repo-relative path to Firebase Admin SDK JSON)

### Optional Target and Merge Variables

- `FCM_DEVICE_TOKENS` (comma-separated direct tokens)
- `FCM_TOPIC` (topic target such as `polaris-alerts`)
- `FCM_INCLUDE_ENV_TOKENS` (`1` to include `.env` tokens even when DB tokens exist)

### Reliability Controls

- `ALERT_DEDUP_SECONDS` (duplicate suppression window; code default `180`)
- `ALERT_RETRY_ENABLED` (default `1`)
- `ALERT_RETRY_INTERVAL_SECONDS` (default `30`)
- `ALERT_RETRY_MAX_ATTEMPTS` (default `3`)
- `ALERT_RETRY_BATCH_SIZE` (default `20`)

### Token and Debug Endpoints

- `POST /alert/register-token`
- `POST /alert/unregister-token`
- `POST /alert/test-token`
- `GET /alert/debug-status`

---

## API Snapshot

### Core Inference and Alerting

- `POST /input/camera`
- `GET /decision/latest`
- `POST /alert/dispatch`
- `GET /backend/health`
- `POST /backend/start`

### Dashboard and Visualization

- `GET /dashboard/current-status`
- `GET /dashboard/risk-timeseries`
- `GET /dashboard/confidence-timeseries`
- `GET /dashboard/eta-timeseries`
- `GET /alerts/latest`
- `GET /alerts/history`
- `GET /map/live-risk`
- `GET /map/safe-zones`
- `GET /map/historical-events`
- `GET /predictions/history`

### Citizen and Authority Flows

- `POST /input/citizen/image`
- `POST /input/citizen/water-level`
- `GET /input/citizen/pending`
- `POST /input/citizen/review`
- `POST /override/set`
- `POST /override/clear`
- `GET /override/history`
- `GET /override/active`
- `POST /authority/feedback/`
- `GET /authority/feedback/active-learning/queue`
- `GET /authority/feedback/active-learning/stats`

### ML Admin

- `POST /admin/ml/retrain-and-reload`
- `GET /admin/ml/status`
- `GET /admin/ml/auto-config`
- `POST /admin/ml/auto-config`

---

## Quick Start (Local)

### Backend

```bash
python -m venv .venv
# activate venv for your shell
pip install -r requirements.txt
uvicorn app.main:app --reload
```

### Flutter Dashboard

```bash
cd polaris_dashboard
flutter pub get
flutter run -d chrome --dart-define=POLARIS_API_BASE_URL=http://127.0.0.1:8000
```

---

## Project Structure

```text
Polaris/
  app/
    main.py
    database.py
    routes/
    notifications/
    utils/
    ai/
  polaris_dashboard/
  polaris_dataset/
  firebase.json
  public/
  README.md
```

---

## Technology Stack

| Layer | Technology |
| --- | --- |
| Backend | FastAPI |
| AI / ML | PyTorch, TorchVision |
| Computer Vision | OpenCV |
| Temporal Learning | LSTM |
| Database | MongoDB |
| Messaging | FCM, optional Valkey Pub/Sub |
| Frontend | Flutter (Web + Android) |
| Mapping | OpenStreetMap |
| Deployment | Firebase Hosting scaffold + cloud-ready backend |

---

## Team

<a href="https://github.com/HarshBavaskar/Polaris/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=HarshBavaskar/Polaris" />
</a>

- **Detection, AI and Dashboard System** - *Harsh Bavaskar*
- **Warning and Notification System** - *Anisa D'souza*

---

## Project Status
[PHASE 1 COMPLETED]
- [x] Detection pipeline complete
- [x] CNN + LSTM integrated
- [x] Citizen and authority feedback loop
- [x] Manual override system live
- [x] Live dashboard and geospatial intelligence operational
- [x] FCM-based web/mobile notifications integrated
- [x] Alert dedup + retry reliability controls implemented

---

## Future Roadmap

- automated safe-zone verification and confidence decay
- hyperlocal sensor fusion
- multi-camera zone mapping
- mobile apps for citizens and field authorities
- pilot deployments with local authorities

---

## Disclaimer

Polaris is an **early warning support system** and does not replace official meteorological agencies.  
It is intended to assist disaster response with faster, hyperlocal insights.

---

> *Polaris aims to detect danger early, when response still matters.*

