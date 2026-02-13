#!/bin/zsh
set -euo pipefail

BACKEND_URL="${POLARIS_BACKEND_URL:-http://127.0.0.1:8000}"

echo "Checking backend at: ${BACKEND_URL}"

health_json="$(curl -sS "${BACKEND_URL}/backend/health" || true)"
if [[ -z "${health_json}" ]]; then
  echo "FAIL: backend is not reachable."
  echo "Run: ./run_phone_https.sh"
  exit 1
fi

echo "PASS: backend reachable."

debug_json="$(curl -sS "${BACKEND_URL}/alert/debug-status")"

python3 - <<'PY' "${debug_json}"
import json
import sys

data = json.loads(sys.argv[1])
fcm = data.get("fcm") or {}

print("")
print("Debug status:")
print(f"- FCM ready: {fcm.get('ready')}")
issues = fcm.get("issues") or []
if issues:
    print("- FCM issues:")
    for issue in issues:
        print(f"  - {issue}")
print(f"- .env token count: {fcm.get('device_tokens_count')}")
print(f"- Registered token count: {fcm.get('registered_tokens_count')}")
print(f"- Topic: {fcm.get('topic')}")
print(f"- Last alert status: {(data.get('last_alert') or {}).get('status')}")
env_count = int(fcm.get("device_tokens_count") or 0)
registered_count = int(fcm.get("registered_tokens_count") or 0)
if registered_count > 0:
    print("- Phone/app registration: OK")
elif env_count > 0:
    print("- Phone/app registration: missing (using .env tokens only)")
else:
    print("- Phone/app registration: missing (no targets configured)")
PY

echo ""
echo "Sending test advisory alert..."
dispatch_json="$(curl -sS -X POST "${BACKEND_URL}/alert/dispatch" \
  -H "Content-Type: application/json" \
  -d '{"title":"Polaris Quick Test","message":"Quick phone notification check","severity":"ADVISORY","channel":"APP_NOTIFICATION","source":"QUICK_CHECK"}')"

python3 - <<'PY' "${dispatch_json}"
import json
import sys

data = json.loads(sys.argv[1])
delivery = data.get("delivery") or {}

print("Dispatch result:")
print(f"- status: {data.get('status')}")
print(f"- delivery ok: {delivery.get('ok')}")
print(f"- provider: {delivery.get('provider')}")

results = ((delivery.get("results") or {}).get("fcm") or {}).get("results") or []
if results:
    first = results[0]
    print(f"- first target: {first.get('target')}")
    print(f"- first target ok: {first.get('ok')}")
    if not first.get("ok"):
        print(f"- first target error: {first.get('resp') or first.get('error')}")
PY

echo ""
echo "If delivery says sent but phone shows nothing:"
echo "1) Keep app open once and allow notifications when prompted."
echo "2) Check /alert/debug-status -> registered_tokens_count should be > 0."
echo "3) On iPhone, open from Safari and Add to Home Screen for web push."
