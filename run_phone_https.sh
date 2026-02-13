#!/bin/zsh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
WEB_PORT="${POLARIS_PHONE_PORT:-8080}"
BACKEND_URL="${POLARIS_BACKEND_URL:-http://127.0.0.1:8000}"
NGROK_API="${NGROK_API:-http://127.0.0.1:4040/api/tunnels}"
NGROK_AUTHTOKEN="${NGROK_AUTHTOKEN:-}"

cleanup() {
  [[ -n "${PROXY_PID:-}" ]] && kill "${PROXY_PID}" >/dev/null 2>&1 || true
  [[ -n "${NGROK_PID:-}" ]] && kill "${NGROK_PID}" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter not found in PATH."
  exit 1
fi
if ! command -v ngrok >/dev/null 2>&1; then
  echo "ngrok not found in PATH."
  exit 1
fi

cd "$REPO_ROOT"

# Optional local env loading for convenience (e.g., NGROK_AUTHTOKEN).
if [[ -f "$REPO_ROOT/.env" ]]; then
  set -a
  source "$REPO_ROOT/.env" >/dev/null 2>&1 || true
  set +a
  NGROK_AUTHTOKEN="${NGROK_AUTHTOKEN:-}"
fi

if [[ -n "$NGROK_AUTHTOKEN" ]]; then
  ngrok config add-authtoken "$NGROK_AUTHTOKEN" >/dev/null 2>&1 || true
fi

echo "1) Starting backend..."
"$REPO_ROOT/app/notifications/run_all.sh"

echo "   Waiting for backend health..."
backend_up="0"
for _ in {1..25}; do
  if curl -fsS "${BACKEND_URL}/backend/health" >/dev/null 2>&1; then
    backend_up="1"
    break
  fi
  sleep 1
done
if [[ "$backend_up" != "1" ]]; then
  echo "Backend did not become healthy in time."
  echo "Check: logs_backend.txt"
  exit 1
fi

echo "2) Building Flutter web (release)..."
cd "$REPO_ROOT/polaris_dashboard"
BUILD_ARGS=(
  web
  --release
  --pwa-strategy=none
  --dart-define=POLARIS_API_BASE_URL=/api
)

if flutter build web -h 2>/dev/null | rg -q -- "--web-renderer"; then
  BUILD_ARGS+=(--web-renderer=canvaskit)
fi

flutter build "${BUILD_ARGS[@]}"

echo "3) Starting local phone proxy..."
cd "$REPO_ROOT"
python3 "$REPO_ROOT/app/notifications/phone_https_proxy.py" \
  --web-root "$REPO_ROOT/polaris_dashboard/build/web" \
  --backend "$BACKEND_URL" \
  --host 127.0.0.1 \
  --port "$WEB_PORT" \
  > "$REPO_ROOT/logs_phone_proxy.txt" 2>&1 &
PROXY_PID=$!

sleep 1
if ! kill -0 "$PROXY_PID" >/dev/null 2>&1; then
  echo "Phone proxy failed to start. Check logs_phone_proxy.txt"
  exit 1
fi

echo "4) Starting ngrok HTTPS tunnel..."
pkill -f "ngrok http ${WEB_PORT}" >/dev/null 2>&1 || true
ngrok http "$WEB_PORT" > "$REPO_ROOT/logs_ngrok.txt" 2>&1 &
NGROK_PID=$!

PUBLIC_URL=""
for _ in {1..30}; do
  sleep 1
  tunnels_json="$(curl -sS "$NGROK_API" || true)"
  if [[ -n "$tunnels_json" ]]; then
    PUBLIC_URL="$(python3 - <<'PY' "$tunnels_json"
import json
import sys

try:
    data = json.loads(sys.argv[1])
except Exception:
    print("")
    raise SystemExit(0)

for t in data.get("tunnels", []):
    url = t.get("public_url", "")
    if url.startswith("https://"):
        print(url)
        raise SystemExit(0)
print("")
PY
)"
    if [[ -n "$PUBLIC_URL" ]]; then
      break
    fi
  fi
done

if [[ -z "$PUBLIC_URL" ]]; then
  echo "Could not get ngrok public URL."
  echo "Check logs_ngrok.txt"
  echo "If needed: ngrok config add-authtoken <token>"
  exit 1
fi

echo
echo "Open this on your phone:"
echo "$PUBLIC_URL"
echo
echo "If ngrok warning page appears, tap: Visit Site."
echo "Then allow notifications when browser asks."
echo
echo "After opening on phone, press Enter here to run automatic quick check."
read -r

POLARIS_BACKEND_URL="$BACKEND_URL" "$REPO_ROOT/quick_phone_check.sh" || true

echo
echo "Keep this terminal open while testing."
echo "If you want another test later, run:"
echo "POLARIS_BACKEND_URL=$BACKEND_URL ./quick_phone_check.sh"

while true; do
  sleep 60
done
