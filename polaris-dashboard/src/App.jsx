import { useEffect, useState } from "react";
import { api } from "./api";
import RiskMap from "./components/RiskMap";

/* =========================
   Priority Computation
   ========================= */
function computePriority(points, decision, safeZones) {
  if (!points || !decision || points.length === 0) return null;

  const top = points.reduce((a, b) =>
    (b.risk_score ?? 0) > (a.risk_score ?? 0) ? b : a
  );

  if (!top || (top.risk_score ?? 0) < 0.45) return null;

  const nearest = [...safeZones]
    .map(z => ({
      ...z,
      distance:
        Math.pow(z.lat - top.lat, 2) + Math.pow(z.lng - top.lng, 2),
    }))
    .sort((a, b) => a.distance - b.distance)
    .slice(0, 2);

  return {
    location: `Lat ${top.lat.toFixed(4)}, Lng ${top.lng.toFixed(4)}`,
    riskLevel: decision.final_risk_level,
    alertSeverity: decision.final_alert_severity,
    eta: decision.final_eta,
    etaConfidence: decision.final_eta_confidence,
    safeZones: nearest,
  };
}

export default function App() {
  /* =========================
     STATE
     ========================= */
  const [decision, setDecision] = useState(null);
  const [alerts, setAlerts] = useState([]);

  const [mapPoints, setMapPoints] = useState([]);
  const [safeZones, setSafeZones] = useState([]);
  const [historicalEvents, setHistoricalEvents] = useState([]);

  const [priority, setPriority] = useState(null);

  const [showHeatmap, setShowHeatmap] = useState(true);
  const [showSafeZones, setShowSafeZones] = useState(true);
  const [showHistory, setShowHistory] = useState(true);

  /* =========================
     FETCH ALL DATA
     ========================= */
  const fetchAll = async () => {
    try {
      const [
        decisionRes,
        alertsRes,
        riskRes,
        safeRes,
        historyRes,
      ] = await Promise.all([
        api.get("/decision/latest"),
        api.get("/alerts/latest"),
        api.get("/map/live-risk"),
        api.get("/map/safe-zones"),
        api.get("/map/historical-events"),
      ]);

      setDecision(decisionRes.data);
      setAlerts(alertsRes.data || []);
      setMapPoints(riskRes.data || []);
      setSafeZones(safeRes.data || []);
      setHistoricalEvents(historyRes.data || []);
    } catch (err) {
      console.error("Dashboard fetch error:", err);
    }
  };

  /* =========================
     AUTO-REFRESH (POLLING)
     ========================= */
  useEffect(() => {
    fetchAll();

    const interval = setInterval(() => {
      fetchAll();
    }, 5000); // refresh every 5s

    return () => clearInterval(interval);
  }, []);

  /* =========================
     PRIORITY PANEL (AI ONLY)
     ========================= */
  useEffect(() => {
    if (
      decision &&
      decision.decision_state !== "MANUAL_OVERRIDE" &&
      mapPoints.length &&
      safeZones.length
    ) {
      setPriority(computePriority(mapPoints, decision, safeZones));
    } else {
      setPriority(null);
    }
  }, [decision, mapPoints, safeZones]);

  /* =========================
     AUTHORITY OVERRIDE ACTIONS
     ========================= */
  const applyOverride = async () => {
    await api.post("/override/set", {
      risk_level: document.getElementById("ov-risk").value,
      alert_severity: document.getElementById("ov-severity").value,
      reason: document.getElementById("ov-reason").value,
      author: "Authority Dashboard",
    });
    fetchAll();
  };

  const clearOverride = async () => {
    await api.post("/override/clear");
    fetchAll();
  };

  return (
    <div className="min-h-screen bg-gray-100 p-6">
      {/* =========================
         OVERRIDE BANNER
         ========================= */}
      {decision?.decision_state === "MANUAL_OVERRIDE" && (
        <div className="bg-red-700 text-white p-3 mb-4 rounded text-center font-bold">
          ⚠️ MANUAL OVERRIDE ACTIVE — AI DECISIONS SUSPENDED
        </div>
      )}

      <h1 className="text-2xl font-bold mb-6">
        Polaris — Authority Dashboard
      </h1>

      {/* =========================
         SYSTEM STATUS
         ========================= */}
      <div className="bg-white p-4 rounded shadow mb-6">
        <h2 className="text-lg font-semibold mb-2">System Status</h2>

        {decision ? (
          <ul className="text-sm space-y-1">
            <li><b>Risk Level:</b> {decision.final_risk_level}</li>
            <li><b>Alert Severity:</b> {decision.final_alert_severity}</li>
            <li>
              <b>ETA:</b> {decision.final_eta} ({decision.final_eta_confidence})
            </li>
            <li><b>Confidence:</b> {decision.final_confidence}</li>
            <li>
              <b>Decision Mode:</b>{" "}
              {decision.decision_state === "MANUAL_OVERRIDE"
                ? "MANUAL OVERRIDE"
                : "Automated"}
            </li>
            <li className="text-gray-600">{decision.justification}</li>
          </ul>
        ) : (
          <p>Loading decision…</p>
        )}
      </div>

      {/* =========================
         AUTHORITY OVERRIDE PANEL
         ========================= */}
      <div className="bg-yellow-50 border-l-4 border-yellow-500 p-4 mb-6 rounded">
        <h2 className="text-lg font-bold text-yellow-700 mb-2">
          🛂 Authority Override
        </h2>

        <div className="flex gap-3 text-sm mb-3">
          <select id="ov-risk" className="border p-1">
            <option>SAFE</option>
            <option>WATCH</option>
            <option>WARNING</option>
            <option>IMMINENT</option>
          </select>

          <select id="ov-severity" className="border p-1">
            <option>INFO</option>
            <option>ADVISORY</option>
            <option>ALERT</option>
            <option>EMERGENCY</option>
          </select>

          <input
            id="ov-reason"
            className="border p-1 flex-1"
            placeholder="Reason for override"
          />
        </div>

        <div className="flex gap-3">
          <button
            className="bg-red-600 text-white px-3 py-1 rounded"
            onClick={applyOverride}
          >
            Apply Override
          </button>

          <button
            className="bg-gray-500 text-white px-3 py-1 rounded"
            onClick={clearOverride}
          >
            Clear Override
          </button>
        </div>
      </div>

      {/* =========================
         PRIORITY PANEL (AI)
         ========================= */}
      {priority && (
        <div className="bg-red-50 border-l-4 border-red-500 p-4 mb-6 rounded">
          <h2 className="text-lg font-bold text-red-700 mb-2">
            🚨 Priority Attention Required
          </h2>

          <ul className="text-sm space-y-1">
            <li><b>Location:</b> {priority.location}</li>
            <li><b>Risk Level:</b> {priority.riskLevel}</li>
            <li><b>Alert Severity:</b> {priority.alertSeverity}</li>
            <li>
              <b>ETA:</b> {priority.eta} ({priority.etaConfidence})
            </li>
          </ul>

          <div className="mt-3">
            <b className="text-sm">Nearest Safe Zones:</b>
            <ul className="list-disc list-inside text-sm">
              {priority.safeZones.map((z, i) => (
                <li key={i}>
                  {z.name} ({z.type}, cap {z.capacity})
                </li>
              ))}
            </ul>
          </div>
        </div>
      )}

      {/* =========================
         MAP CONTROLS
         ========================= */}
      <div className="bg-white p-4 rounded shadow mb-4">
        <h2 className="text-lg font-semibold mb-2">Map Layers</h2>

        <div className="flex gap-6 text-sm">
          <label>
            <input
              type="checkbox"
              checked={showHeatmap}
              onChange={() => setShowHeatmap(!showHeatmap)}
            />{" "}
            Live Risk Heatmap
          </label>

          <label>
            <input
              type="checkbox"
              checked={showSafeZones}
              onChange={() => setShowSafeZones(!showSafeZones)}
            />{" "}
            Safe Zones
          </label>

          <label>
            <input
              type="checkbox"
              checked={showHistory}
              onChange={() => setShowHistory(!showHistory)}
            />{" "}
            Historical Events
          </label>
        </div>

        {decision?.decision_state === "MANUAL_OVERRIDE" && (
          <p className="text-xs text-gray-500 mt-2">
            AI predictions shown for reference only during manual override
          </p>
        )}
      </div>

      {/* =========================
         MAP
         ========================= */}
      <div className="bg-white p-4 rounded shadow mb-4">
        <RiskMap
          points={showHeatmap ? mapPoints : []}
          safeZones={showSafeZones ? safeZones : []}
          historicalEvents={showHistory ? historicalEvents : []}
        />
      </div>

      {/* =========================
         ALERTS
         ========================= */}
      <div className="bg-white p-4 rounded shadow">
        <h2 className="text-lg font-semibold mb-2">Recent Alerts</h2>

        <table className="w-full text-sm">
          <thead>
            <tr className="border-b">
              <th className="text-left">Time</th>
              <th className="text-left">Channel</th>
              <th className="text-left">Severity</th>
              <th className="text-left">Message</th>
            </tr>
          </thead>
          <tbody>
            {alerts.map((a, i) => (
              <tr key={i} className="border-b">
                <td>{new Date(a.timestamp).toLocaleString()}</td>
                <td>{a.channel}</td>
                <td>{a.severity}</td>
                <td>{a.message}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
