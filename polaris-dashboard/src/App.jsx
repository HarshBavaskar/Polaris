import { useEffect, useState } from "react";
import { api } from "./api";
import RiskMap from "./components/RiskMap";

/* =========================
   Priority Computation
   ========================= */
function computePriority(points, decision, safeZones) {
  if (!points || points.length === 0 || !decision) return null;

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
     State
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
     Data Fetch
     ========================= */
  useEffect(() => {
    api.get("/decision/latest").then(res => setDecision(res.data));
    api.get("/alerts/latest").then(res => setAlerts(res.data));
    api.get("/map/live-risk").then(res => setMapPoints(res.data));
    api.get("/map/safe-zones").then(res => setSafeZones(res.data));
    api.get("/map/historical-events").then(res => setHistoricalEvents(res.data));
  }, []);

  /* =========================
     Priority Calculation
     ========================= */
  useEffect(() => {
    if (decision && mapPoints.length && safeZones.length) {
      setPriority(computePriority(mapPoints, decision, safeZones));
    } else {
      setPriority(null);
    }
  }, [decision, mapPoints, safeZones]);

  return (
    <div className="min-h-screen bg-gray-100 p-6">
      <h1 className="text-2xl font-bold mb-6">
        Polaris — Authority Dashboard
      </h1>

      {/* =========================
         Current Status
         ========================= */}
      <div className="bg-white p-4 rounded shadow mb-6">
        <h2 className="text-lg font-semibold mb-2">Current System Status</h2>

        {decision ? (
          <ul className="text-sm space-y-1">
            <li><b>Risk Level:</b> {decision.final_risk_level}</li>
            <li><b>Alert Severity:</b> {decision.final_alert_severity}</li>
            <li><b>ETA:</b> {decision.final_eta} ({decision.final_eta_confidence})</li>
            <li><b>Confidence:</b> {decision.final_confidence}</li>
            <li className="text-gray-600">{decision.justification}</li>
          </ul>
        ) : (
          <p>Loading status…</p>
        )}
      </div>

      {/* =========================
         Priority Panel
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
         Map Layer Toggles
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
            Historical Incidents
          </label>
        </div>
      </div>

      {/* =========================
         Risk Map
         ========================= */}
      <div className="bg-white p-4 rounded shadow mb-4">
        <h2 className="text-lg font-semibold mb-2">
          Live Cloudburst Risk Map
        </h2>

        <RiskMap
          points={showHeatmap ? mapPoints : []}
          safeZones={showSafeZones ? safeZones : []}
          historicalEvents={showHistory ? historicalEvents : []}
        />
      </div>

      {/* =========================
         Legend
         ========================= */}
      <div className="bg-white p-4 rounded shadow mb-6 text-sm">
        <h2 className="font-semibold mb-2">Map Legend</h2>
        <ul className="space-y-1">
          <li>🔥 <b>Heatmap</b>: Higher intensity = higher risk</li>
          <li>🟢 <b>Safe Zones</b>: Evacuation / shelter locations</li>
          <li>🔴 <b>Historical Events</b>: Past cloudburst incidents</li>
        </ul>
      </div>

      {/* =========================
         Alerts Table
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
