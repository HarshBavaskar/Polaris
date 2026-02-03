<div align="center">

<img src="misc/Polaris.PNG" height="250"/>

| **Current Version** | `v0.4: Pre-Release` |
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

## What’s New in v0.4 (Major Update)

### 🔐 Authority Override (System-Wide)
- Manual authority override **globally supersedes AI**
- Override applies **instantly**, without new sensor input
- Centralized at `GET /decision/latest` (single source of truth)
- Fully auditable (author, reason, timestamp)

### 🧠 Final Decision Authority
- AI outputs no longer conflict or fragment
- One unified decision object:
  - Risk level
  - Alert severity
  - ETA + ETA confidence
  - Decision mode (`AUTOMATED` / `MANUAL_OVERRIDE`)
- Used consistently by dashboard, alerts, and all client applications

### 🗺️ Live Risk Mapping
- Real-time cloudburst risk heatmap
- Historical cloudburst incident overlay
- Safe zones layer (currently static; auto-detection planned)
- Auto-focus and pulse highlighting of highest-risk regions

### 🚨 Escalation-Based Alerting
- Severity escalation logic:
  - `INFO → ADVISORY → ALERT → EMERGENCY`
- Driven by:
  - Risk level
  - ETA
  - Confidence
  - Temporal probability
- Cooldown enforcement per channel to prevent alert spam

### 📡 Dashboard-First Architecture
- Production-grade React dashboard (no Streamlit)
- Polling-based live updates (5-second refresh)
- Designed for command-center and authority-level operations

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
Alert Escalation Engine
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

### Dashboard & Visualization
- Production-grade React dashboard
- Live auto-updating system state (polling-based)
- Manual override dominance clearly indicated
- Interactive map with:
  - Live risk heatmap
  - Historical cloudburst incidents
  - Safe zones layer
- Designed for command-center usage

### Authority Control (v0.4)
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

## Notification & Alert Routing

- API-based **alert routing system** triggered by final decisions  
- Severity-based alert handling:
  - **INFO** – No alert
  - **ADVISORY** – Stay alert
  - **ALERT** – Prepare and restrict movement
  - **EMERGENCY** – Immediate action required
- Cooldown enforcement per channel
- Manual override always supersedes AI

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

---

## Dashboard & System APIs

### Dashboard APIs
- `/dashboard/risk-timeseries`
- `/dashboard/confidence-timeseries`
- `/dashboard/current-status`
- `/alerts/latest`
- `/map/live-risk`
- `/map/safe-zones`
- `/map/historical-events`

### Core System APIs
- `GET  /decision/latest` – Authoritative system decision  
- `POST /alert/dispatch` – Dispatch alert payload  
- `POST /input/camera` – Camera image input  
- `POST /override/set` – Authority override  
- `POST /override/clear` – Clear override  

Compatible with:
- React
- Grafana
- Power BI
- Postman

---

## Postman Integration

- All core APIs are testable via **Postman**
- Used for **live decision → alert validation**
- Enables backend testing without frontend dependency

---

## Project Structure

```
Polaris/
├── app/
│   ├── main.py
│   ├── database.py
│   ├── routes/
│   │   ├── override.py
│   │   ├── dashboard.py
│   │   └── feedback.py
│   ├── utils/
│   │   ├── final_decision.py
│   │   ├── alert_severity.py
│   │   └── eta_logic.py
│   ├── ai/
│   │   ├── infer.py
│   │   └── temporal_infer.py
│   └── notifications/
│       ├── thresholds.py
│       ├── alert_engine.py
│       └── router_client.py
├── polaris-dashboard/
├── polaris_dataset/
├── camera_client.py
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
| Frontend | React + Vite + Tailwind |
| Mapping | Leaflet |
| Notifications | API-based (HTTP / Postman) |
| Deployment | Cloud-ready |

---

## Team

<a href="https://github.com/HarshBavaskar/Polaris/graphs/contributors">
<img src="https://contrib.rocks/image?repo=HarshBavaskar/Polaris" />
</a>  

##

- **Detection & AI System** – *Harsh Bavaskar*  
  (CNN, LSTM, rule-based logic, data collection, detection pipeline)

- **Warning & Notification System** – *Anisa D'souza*  
  (API routing, alert logic, Postman integration)
---

---

## Project Status

- ✅ Detection pipeline complete
- ✅ CNN + LSTM integrated
- ✅ Citizen & authority feedback loop
- ✅ Final decision authority implemented
- ✅ Manual override system live
- ✅ Live dashboard & geospatial map operational
- 🔄 Continuous data collection & learning

---

## Future Roadmap

- Automatic safe-zone detection
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
