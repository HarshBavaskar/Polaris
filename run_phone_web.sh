#!/bin/zsh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter not found in PATH."
  exit 1
fi

if ! command -v ipconfig >/dev/null 2>&1; then
  echo "ipconfig not found. This script currently supports macOS."
  exit 1
fi

cd "$REPO_ROOT"

echo "Starting Polaris backend..."
"$REPO_ROOT/app/notifications/run_all.sh"

DEFAULT_IFACE="$(route -n get default 2>/dev/null | awk '/interface:/{print $2; exit}')"
LAN_IP=""

if [[ -n "${DEFAULT_IFACE}" ]]; then
  LAN_IP="$(ipconfig getifaddr "$DEFAULT_IFACE" 2>/dev/null || true)"
fi
if [[ -z "${LAN_IP}" ]]; then
  LAN_IP="$(ipconfig getifaddr en0 2>/dev/null || true)"
fi
if [[ -z "${LAN_IP}" ]]; then
  LAN_IP="$(ipconfig getifaddr en1 2>/dev/null || true)"
fi

if [[ -z "${LAN_IP}" ]]; then
  echo "Could not detect LAN IP automatically."
  echo "Run manually with:"
  echo "flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 --dart-define=POLARIS_API_BASE_URL=http://<YOUR_LAPTOP_IP>:8000"
  exit 1
fi

echo
echo "Backend URL: http://${LAN_IP}:8000"
echo "Phone URL:   http://${LAN_IP}:8080"
echo
echo "Open the Phone URL on your phone (same Wi-Fi)."
echo "Starting Flutter web server (phone-first mode)..."

cd "$REPO_ROOT/polaris_dashboard"
RUN_ARGS=(
  -d web-server
  --web-hostname 0.0.0.0
  --web-port 8080
  --dart-define=POLARIS_API_BASE_URL=http://${LAN_IP}:8000
)

if flutter run --help 2>/dev/null | rg -q -- "--web-renderer"; then
  RUN_ARGS+=(--web-renderer=canvaskit)
fi

exec flutter run "${RUN_ARGS[@]}"
