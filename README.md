<div align="center">

<img src="misc/Polaris_Logo_Side.PNG" height="250"/>

| **Current Version** | `v0.8: Operational Intelligence, Live Reliability, and ML Automation Release` |
| --- | --- |

</div>

---

> **An AI-powered, real-time, hyperlocal cloudburst early warning and decision system**  
> combining **computer vision**, **temporal intelligence**, and **human-in-the-loop authority**.

---

## Overview

**Polaris** is a research-grade early warning and decision system designed to detect **cloudburst-like conditions before severe impact occurs**.  
Unlike traditional threshold-based systems, Polaris uses a **layered intelligence approach** that fuses:

- Visual understanding of the sky  
- Temporal pattern learning  
- Citizen-ground reports  
- Rule-based safety logic  
- Authority override controls  

The result is a **trustworthy, explainable, and deployable** disaster-support system.

---

## What’s New in Polaris v0.8 
### Operational Intelligence, Live Reliability, and ML Automation Release

Polaris v0.8 introduces operational-grade ML automation, active learning, reliability upgrades, and deeper AI fusion logic. This release strengthens decision stability, training workflows, and real-time dashboard behavior.

---

## Polaris v0.8 Dashboard UI
<div align ="center">
<img src="misc/Polaris Dashboard Demo.gif"/>
</div>

---

## ML Automation & Active Learning

- Added full **ML Admin Controls** inside Settings:
  - Train Now
  - Auto-training toggle
  - Threshold selection
  - Live ML job status

- Implemented one-click backend ML pipeline:
  - Dataset build
  - CNN retraining
  - LSTM retraining
  - Hot reload without manual restart

- Added auto-training trigger based on feedback volume threshold
- Introduced active learning pipeline:
  - Uncertain sample queueing
  - Feedback-aware biasing
  - Labeled sample tracking
  - Queue and stats endpoints

- Hardened training pipeline:
  - Sparse temporal data now returns `SUCCESS_WITH_WARNINGS`
  - Prevents full job failure on partial datasets

---

## AI Decision Engine Upgrades

- Implemented ensemble scoring:
  - Rule-based risk
  - CNN probability
  - Temporal probability
  - Trend / spike detection
  - Feedback bias contribution

- Upgraded confidence and fusion logic:
  - Smoother decision transitions
  - Reduced brittle risk jumps
  - Improved stability under rapid environmental shifts

- Fixed Trends chart issue:
  - Aligned backend/UI risk keys
  - Added support for `ensemble_score`

---

## Settings & Operational Controls

- Added full **Settings tab** with:
  - App versioning
  - Backend health and stats
  - Dark mode toggle
  - Backend start/stop controls
  - Terminal visibility toggle

- Implemented Windows backend launcher improvements:
  - Hidden shell support
  - Optional visible terminal
  - Improved stop workflow behavior

---

## Dashboard Reliability & UX Refinement

- Improved Overview screen:
  - Compact important stats
  - Map-summary-based live risk counts
  - Corrected auto-refresh behavior

- Improved Map screen:
  - Continuous reflection of latest decision risk
  - Fallback marker support

- Added severity-aware marquee in top bar:
  - Color-coded by alert level
  - Filters only active alerts

- Implemented startup loader flow
- Refined animations and surface transitions:
  - Attention pulses
  - Smoother non-flicker updates

- Added safer automatic polling across:
  - Overview
  - Settings
  - Citizen Verification
  - Trends
  - Alerts
  - Map

---

Polaris v0.8 strengthens operational intelligence, improves ML autonomy, enhances reliability under live conditions, and moves the system closer to continuous-learning deployment.

---

## System Architecture

```
Camera / Images
↓
Image Feature Extraction
(Brightness • Entropy • Edges)
↓
Rule-Based Risk Logic
↓
Time-Series Spike Detection
↓
CNN (Spatial AI)
↓
LSTM (Temporal AI)
↓
Citizen Input Fusion
↓
Safe Decision Fusion
(Never Downgrade)
↓
Final Decision Authority
(AI OR Manual Override)
↓
Decision Publication (Valkey)
↓
Automated Alert Routing
↓
MongoDB + Dashboard & Map APIs
```

---

## Key Capabilities

### Vision-Based Detection
- Camera-based sky monitoring (currently laptop camera)
- CNN learns cloud and storm visual patterns
- Works even before rainfall begins

### Temporal Intelligence
- LSTM model learns **how conditions evolve**
- Detects **rapid escalation**, not isolated frames
- Significantly reduces false positives

### Citizen Intelligence
- Citizen-uploaded images
- Water-level reports (Ankle / Knee / Waist)
- Human inputs influence risk but do not bypass safety logic

### Ensemble Risk Engine (v0.8)
- *Combines:*
- Rule-based safety logic
- CNN spatial probability
- LSTM temporal probability
- Trend / spike detection
- Feedback bias weighting
- Stability smoothing prevents brittle decision jumps
- Produces ensemble_score for consistent UI alignment

### Active Learning & ML Automation
- Uncertain sample queueing
- Feedback-aware retraining bias
- Auto-training triggered by feedback threshold
- *One-click ML pipeline:*
- Dataset build
- CNN retrain
- LSTM retrain
- Hot reload
- Sparse temporal datasets return SUCCESS_WITH_WARNINGS (no full failure)

### Dashboard & Visualization
- Production-grade command-center dashboard
- Global auto-refresh (no manual reload)
- Manual override dominance clearly indicated
- Interactive map with:
  - Live risk heatmap
  - Historical cloudburst incidents
  - Safe zones with confidence
- Designed for authority decision-making

### Authority Control (v0.4+)
- Manual authority override with global precedence
- Override applies instantly system-wide
- Fully auditable (author, reason, timestamp)

### Explainable Decisions
Every prediction includes:
- Risk score
- Risk level
- Confidence score
- AI probability (CNN)
- Temporal probability (LSTM)
- ETA, ETA confidence
- Decision mode (AUTOMATED / MANUAL_OVERRIDE)

---

## Authority Feedback Loop

- Alerts can be marked as:
  - TRUE_POSITIVE
  - FALSE_POSITIVE
  - LATE_DETECTION
- Feedback stored for **future retraining and evaluation**

---

## AI Models Used

### Spatial AI (CNN)
- Architecture: **MobileNetV2**
- Task: Identify high-risk cloud patterns
- Output: Probability of high-risk frame

### Temporal AI (LSTM)
- Input: Sequences of numeric features
- Learns escalation trends across time
- Core component for early warning

> ⚠️ Rule-based logic is **never removed** and always acts as a safety fallback.

---

## Data Storage (MongoDB)

Collections:
- `alerts` – alert metadata  
- `images` – image metadata  
- `predictions` – risk, confidence, AI outputs  
- `citizen_reports` – public inputs  
- `feedback` – authority verification  
- `overrides` – manual authority decisions  
- `safe_zones` – automated & manual safe zones  

---

## Dashboard & System APIs

### Dashboard APIs

- `GET /dashboard/current-status` – Live authoritative system state (risk, ensemble score, mode, confidence)
- `GET /dashboard/risk-timeseries` – Risk + ensemble score evolution
- `GET /dashboard/confidence-timeseries` – Confidence trend data
- `GET /dashboard/system-stats` – Backend health, ML status, version info
- `GET /alerts/latest` – Latest active alerts
- `GET /alerts/history` – Historical alerts
- `GET /map/live-risk` – Current geospatial risk layer
- `GET /map/safe-zones` – Manual & automated safe zones
- `GET /map/historical-events` – Past incidents overlay
- `GET /citizen/pending` – Pending citizen reports
- `GET /citizen/history` – Reviewed citizen reports

---

### ML & Active Learning APIs (v0.8)

- `POST /ml/train` – Trigger one-click ML pipeline  
- `GET  /ml/status` – Current ML job status  
- `POST /ml/auto-toggle` – Enable/disable auto-training  
- `GET  /ml/auto-config` – Auto-training threshold configuration  
- `GET  /ml/uncertain-queue` – Active learning queue statistics  
- `GET  /ml/training-history` – Past ML job summaries  

Pipeline includes:
- Dataset build  
- CNN retraining  
- LSTM retraining  
- Hot reload of inference engine  

---

### Core System APIs

- `GET  /decision/latest` – Authoritative final decision (ensemble-aware)  
- `POST /input/camera` – Camera image input  
- `POST /alert/dispatch` – Dispatch alert payload  
- `POST /override/set` – Set authority override  
- `POST /override/clear` – Clear authority override  
- `POST /feedback/submit` – Submit authority feedback  
- `GET  /health` – Backend health check  
- `POST /backend/start` – Backend start trigger (Windows launcher integration)  
- `POST /backend/stop` – Controlled backend shutdown  

---

### Compatible With

- Flutter (Web)
- React
- Grafana
- Power BI
- Swagger UI
- Postman (optional, not required for automated operation)
---

## Notification & Alert Routing

- Triggered by final decisions published via Valkey
- Runs continuously once the system is started
- Manual override always supersedes AI decisions

### Alert Severity Levels
- **INFO** – No alert
- **ADVISORY** – Stay alert
- **ALERT** – Prepare and restrict movement
- **EMERGENCY** – Immediate action required

---

## Postman Integration

- Used strictly for API testing and validation
- Helpful during development and debugging
- Not required for normal automated system operation

---

## Project Structure

```
Polaris/
├── app/
│   ├── main.py
│   ├── database.py
│   ├── lifespan.py
│   ├── routes/
│   │   ├── override.py
│   │   ├── dashboard.py
|   |   ├── camera.py
│   │   ├── map.py
│   │   ├── alerts.py
│   │   ├── decision.py
│   │   └── feedback.py
│   ├── utils/
│   │   ├── final_decision.py
│   │   ├── alert_severity.py
│   │   ├── eta_logic.py
│   │   ├── eta_confidence.py
│   │   ├── safezone_detector.py
│   │   ├── escalation_rules.py
│   │   └── confidence_logic.py
│   ├── ai/
│   │   ├── infer.py
│   │   ├── temporal_infer.py
│   │   ├── train_cnn.py
│   │   └── train_lstm.py
│   ├── notifications/
│   │   ├── thresholds.py
│   │   ├── alert_engine.py
│   │   ├── router_client.py
│   │   ├── valkey_pub.py
│   │   ├── valkey_router.py
│   │   ├── deliver.py
│   │   └── run_all.sh
│   └── models/
│       ├── prediction.py
│       ├── override.py
│       └── safezone.py
├── polaris-dashboard/
│   ├── lib/
│   │   ├── core/
│   │   │   ├── api_service.dart
│   │   │   ├── global_reload.dart
│   │   │   └── models/
│   │   ├── layout/
│   │   │   ├── app_shell.dart
│   │   │   ├── side_nav.dart
│   │   │   └── top_bar.dart
│   │   ├── screens/
│   │   │   ├── overview_screen.dart
│   │   │   ├── map_screen.dart
│   │   │   ├── alerts_screen.dart
│   │   │   ├── trends_screen.dart
│   │   │   └── authority_screen.dart
│   │   └── main.dart
│   ├── assets/
│   │   └── polaris_logo.png
│   └── pubspec.yaml
├── polaris_dataset/
├── camera_client.py
├── CHANGELOG.md
└── README.md

```

---

## Technology Stack

| Layer | Technology |
|------|-----------|
| Backend | FastAPI |
| AI / ML | PyTorch, TorchVision |
| Computer Vision | OpenCV |
| Temporal Learning | LSTM |
| Database | MongoDB |
| Messaging | Valkey (Pub/Sub) |
| Frontend | Flutter (Web) |
| Mapping | OpenStreetMap |
| Deployment | Cloud-ready |

---

## Team

<a href="https://github.com/HarshBavaskar/Polaris/graphs/contributors">
<img src="https://contrib.rocks/image?repo=HarshBavaskar/Polaris" />
</a>  

##

- **Detection, AI & Dashboard System** – *Harsh Bavaskar*  
  (CNN, LSTM, decision fusion, safe zones, dashboard, geospatial intelligence)

- **Warning & Notification System** – *Anisa D'souza*  
  (Valkey routing, alert logic, notification pipeline, SMS integration)

---

## Project Status

- ✅ Detection pipeline complete
- ✅ CNN + LSTM integrated
- ✅ Citizen & authority feedback loop
- ✅ Final decision authority implemented
- ✅ Manual override system live
- ✅ Live dashboard & geospatial intelligence operational
- ✅ Trends & analytics available
- ✅ Continuous data collection & learning
- ✅ Automated alert routing (Valkey)
- 🔄 SMS delivery integration in progress


---

## Future Roadmap

- Automated safe-zone verification & confidence decay
- Hyperlocal sensor fusion
- Multi-camera zone mapping
- Mobile apps for citizens & field authorities
- Pilot deployments with local authorities

---

## Disclaimer

Polaris is an **early warning support system** and does not replace official meteorological agencies.  
It is intended to **assist disaster response** with faster, hyperlocal insights.

---

## What Makes Polaris Different

- Not a black-box AI
- Human-in-the-loop by design
- Time-aware, not frame-based
- Built for **trust, safety, and real-world deployment**

---

> *Polaris aims to detect danger early — when response still matters.*


