<div align="center">

<img src="misc/Polaris.PNG" height="250"/>

| **Current Version** | `v0.5: Pre-Release` |
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


## What’s New in v0.5 (Major Update)

### 🔄 Automated Decision-to-Alert Flow
- Final decisions are automatically propagated without manual triggers
- End-to-end pipeline runs continuously once services are started
- Removes dependency on manual API calls for alert activation

### 📦 Valkey Event Bus Integration
- Valkey introduced as an event-driven messaging layer
- AI decisions published to a dedicated channel
- Notification router subscribes and reacts in real time
- Clean decoupling between detection logic and alert delivery

### 🚀 System Orchestration
- Shell-based startup script to launch:
  - Valkey service
  - FastAPI backend
  - Notification router
- Simplifies local runs and pre-deployment testing
- Reduces multi-terminal operational overhead

### 📲 SMS Notification Preparation
- Alert delivery interface structured for SMS integration
- Delivery status tracking (`queued`, `sent`, `failed`)
- Gateway integration planned as next deployment step

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
│       ├── router_client.py
│       ├── valkey_pub.py
│       ├── valkey_router.py
│       └── run_all.sh
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
| Messaging | Valkey (Pub/Sub) |
| Frontend | React + Vite + Tailwind |
| Mapping | Leaflet |
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
  (API routing, alert logic, Postman integration, Valkey integration)
---

## Project Status

- ✅ Detection pipeline complete
- ✅ CNN + LSTM integrated
- ✅ Citizen & authority feedback loop
- ✅ Final decision authority implemented
- ✅ Manual override system live
- ✅ Live dashboard & geospatial map operational
- ✅ Automated alert routing (Valkey)
- 🔄 SMS delivery integration in progress
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

