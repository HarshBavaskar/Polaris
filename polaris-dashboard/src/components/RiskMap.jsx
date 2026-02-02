import {
  MapContainer,
  TileLayer,
  Marker,
  Popup,
  useMap,
  Circle,
} from "react-leaflet";
import { useEffect, useRef, useState } from "react";
import L from "leaflet";
import "leaflet/dist/leaflet.css";
import "leaflet.heat";

/* =========================
   Heatmap Layer
   ========================= */
function HeatLayer({ points }) {
  const map = useMap();

  useEffect(() => {
    if (!points || points.length === 0) return;

    const heatData = points.map(p => [
      p.lat,
      p.lng,
      p.risk_score ?? 0.4,
    ]);

    const heatLayer = L.heatLayer(heatData, {
      radius: 30,
      blur: 20,
      maxZoom: 12,
    });

    heatLayer.addTo(map);

    return () => {
      map.removeLayer(heatLayer);
    };
  }, [points, map]);

  return null;
}

/* =========================
   Auto-Focus + Pulse Target
   ========================= */
function RiskPulse({ points }) {
  const map = useMap();
  const lastFocusKey = useRef(null);
  const [target, setTarget] = useState(null);
  const [pulse, setPulse] = useState(0);

  useEffect(() => {
    if (!points || points.length === 0) return;

    const top = points.reduce((a, b) =>
      (b.risk_score ?? 0) > (a.risk_score ?? 0) ? b : a
    );

    if (!top || (top.risk_score ?? 0) < 0.45) {
      setTarget(null);
      return;
    }

    const key = `${top.lat},${top.lng}`;
    if (lastFocusKey.current !== key) {
      lastFocusKey.current = key;
      map.flyTo([top.lat, top.lng], 14, { duration: 1.5 });
      setTarget(top);
    }
  }, [points, map]);

  /* Pulse animation */
  useEffect(() => {
    if (!target) return;

    const interval = setInterval(() => {
      setPulse(p => (p + 1) % 10);
    }, 300);

    return () => clearInterval(interval);
  }, [target]);

  if (!target) return null;

  return (
    <Circle
      center={[target.lat, target.lng]}
      radius={200 + pulse * 20}
      pathOptions={{
        color: "red",
        fillColor: "red",
        fillOpacity: 0.15 - pulse * 0.01,
      }}
    />
  );
}

/* =========================
   Marker Icons
   ========================= */
const safeZoneIcon = new L.Icon({
  iconUrl:
    "https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-green.png",
  shadowUrl:
    "https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png",
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41],
});

const historicalIcon = new L.Icon({
  iconUrl:
    "https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-red.png",
  shadowUrl:
    "https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png",
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41],
});

/* =========================
   Main Risk Map
   ========================= */
export default function RiskMap({
  points = [],
  safeZones = [],
  historicalEvents = [],
}) {
  return (
    <MapContainer
      center={[19.0760, 72.8777]}
      zoom={12}
      style={{ height: "400px", width: "100%" }}
      className="rounded"
    >
      <TileLayer
        attribution="© OpenStreetMap contributors"
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
      />

      {/* Auto-focus + Pulse Highlight */}
      <RiskPulse points={points} />

      {/* Heatmap */}
      <HeatLayer points={points} />

      {/* Safe Zones */}
      {safeZones.map((z, i) => (
        <Marker key={`safe-${i}`} position={[z.lat, z.lng]} icon={safeZoneIcon}>
          <Popup>
            <b>{z.name}</b>
            <br />
            Type: {z.type}
            <br />
            Capacity: {z.capacity}
          </Popup>
        </Marker>
      ))}

      {/* Historical Events */}
      {historicalEvents.map((e, i) => (
        <Marker
          key={`hist-${i}`}
          position={[e.lat, e.lng]}
          icon={historicalIcon}
        >
          <Popup>
            <b>{e.location}</b>
            <br />
            Date: {e.date}
            <br />
            Severity: {e.severity}
            <br />
            Source: {e.source}
          </Popup>
        </Marker>
      ))}
    </MapContainer>
  );
}
