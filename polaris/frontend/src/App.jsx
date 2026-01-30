import { useEffect, useState } from "react";

function App() {
  const [alerts, setAlerts] = useState([]);
  const [status, setStatus] = useState("SAFE");

  useEffect(() => {
    const interval = setInterval(() => {
      const riskScore = Math.floor(Math.random() * 100);

      let level = "SAFE";
      if (riskScore > 70) level = "RED ALERT";
      else if (riskScore > 40) level = "ORANGE ALERT";

      setStatus(level);

      setAlerts((prev) => [
        {
          time: new Date().toLocaleTimeString(),
          location: "Zone-A",
          risk: riskScore,
          level
        },
        ...prev.slice(0, 5)
      ]);
    }, 3000);

    return () => clearInterval(interval);
  }, []);

  return (
    <div style={{ padding: "20px", fontFamily: "Arial" }}>
      <h1>🌩️ POLARIS</h1>
      <h3>Cloudburst Early Warning – Central Dashboard</h3>

      <hr />

      <h2>🚨 Current System Status</h2>
      <div
        style={{
          padding: "20px",
          width: "250px",
          color: "white",
          textAlign: "center",
          fontSize: "22px",
          fontWeight: "bold",
          borderRadius: "8px",
          background:
            status === "RED ALERT"
              ? "#d32f2f"
              : status === "ORANGE ALERT"
              ? "#f57c00"
              : "#388e3c"
        }}
      >
        {status}
      </div>

      <hr />

      <h2>📊 Recent Alerts</h2>
      <table
        border="1"
        cellPadding="10"
        style={{ borderCollapse: "collapse", width: "100%" }}
      >
        <thead style={{ background: "#f0f0f0" }}>
          <tr>
            <th>Time</th>
            <th>Location</th>
            <th>Risk Score</th>
            <th>Alert Level</th>
          </tr>
        </thead>
        <tbody>
          {alerts.map((alert, index) => (
            <tr key={index}>
              <td>{alert.time}</td>
              <td>{alert.location}</td>
              <td>{alert.risk}</td>
              <td>{alert.level}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export default App;
