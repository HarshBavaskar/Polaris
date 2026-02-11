from datetime import datetime, timedelta
from math import radians, cos, sin, sqrt, atan2
from statistics import mean

# ----------------------------------
# Distance helper (Haversine)
# ----------------------------------
def haversine(lat1, lon1, lat2, lon2):
    R = 6371000  # meters
    phi1, phi2 = radians(lat1), radians(lat2)
    dphi = radians(lat2 - lat1)
    dlambda = radians(lon2 - lon1)

    a = sin(dphi/2)**2 + cos(phi1)*cos(phi2)*sin(dlambda/2)**2
    return 2 * R * atan2(sqrt(a), sqrt(1 - a))


# ----------------------------------
# Step A: Filter low-risk points
# ----------------------------------
def filter_low_risk(points, threshold=0.45):
    return [p for p in points if p["risk_score"] < threshold]


# ----------------------------------
# Step B: Remove historically unsafe points
# ----------------------------------
def filter_historical(points, history, min_distance=500):
    safe = []
    for p in points:
        too_close = False
        for h in history:
            d = haversine(p["lat"], p["lng"], h["lat"], h["lng"])
            if d < min_distance:
                too_close = True
                break
        if not too_close:
            safe.append(p)
    return safe


# ----------------------------------
# Step C: Stability check
# ----------------------------------
def filter_stable(points, risk_history, window=3):
    stable = []
    for p in points:
        key = f"{round(p['lat'],4)}_{round(p['lng'],4)}"
        history = risk_history.get(key, [])
        if len(history) >= window:
            if history[-1] <= mean(history):
                stable.append(p)
    return stable


# ----------------------------------
# Step D: Cluster nearby safe points
# ----------------------------------
def cluster_safezones(points, cluster_radius=300):
    clusters = []

    for p in points:
        added = False
        for c in clusters:
            d = haversine(p["lat"], p["lng"], c["lat"], c["lng"])
            if d < cluster_radius:
                c["points"].append(p)
                added = True
                break
        if not added:
            clusters.append({
                "lat": p["lat"],
                "lng": p["lng"],
                "points": [p]
            })

    return clusters


# ----------------------------------
# Step E: Rank safe zones
# ----------------------------------
def rank_safezones(clusters):
    results = []
    for i, c in enumerate(clusters):
        avg_risk = mean(p["risk_score"] for p in c["points"])
        score = round(1 - avg_risk, 3)

        results.append({
        "id": f"SZ-{i+1}",
        "lat": c["lat"],
        "lng": c["lng"],
        "radius": 300,
        "safety_score": score,
        "confidence_score": score,
        "confidence_level": (
            "HIGH" if score > 0.8 else
            "MEDIUM" if score > 0.6 else
        "LOW"
        ),
        "last_verified": datetime.now().isoformat(),
        "reason": "Low historical risk and stable conditions"
})


#Confidenc Decay Over Time

def apply_confidence_decay(zone, minutes_elapsed):
    decay_rate = 0.02  # per minute
    decayed = max(0.0, zone["confidence_score"] - decay_rate * minutes_elapsed)

    zone["confidence_score"] = round(decayed, 2)
    zone["confidence_level"] = (
        "HIGH" if decayed > 0.8 else
        "MEDIUM" if decayed > 0.6 else
        "LOW"
    )
    return zone

def persist_safezones(zones, collection):
    now = datetime.now()

    for z in zones:
        expires_at = now + timedelta(minutes=30)

        collection.update_one(
            {"zone_id": z["id"]},
            {
                "$set": {
                    "lat": z["lat"],
                    "lng": z["lng"],
                    "radius": z["radius"],
                    "confidence_score": z["confidence_score"],
                    "confidence_level": z["confidence_level"],
                    "last_verified": now,
                    "expires_at": expires_at,
                    "source": "AUTO",
                    "active": True,
                    "reason": z["reason"]
                }
            },
            upsert=True
        )
