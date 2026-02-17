#!/bin/zsh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
BACKEND_URL="${POLARIS_BACKEND_URL:-http://127.0.0.1:8000}"

cd "$REPO_ROOT"

echo "1) Running Python syntax checks..."
python3 -m py_compile \
  app/main.py \
  app/database.py \
  app/notifications/fcm_push.py \
  app/notifications/phone_https_proxy.py
echo "   PASS: syntax checks"

echo "2) Checking backend health..."
if ! curl -fsS "${BACKEND_URL}/backend/health" >/dev/null 2>&1; then
  echo "   Backend not up. Starting backend..."
  "$REPO_ROOT/app/notifications/run_all.sh" >/dev/null 2>&1 || true
fi

backend_up="0"
for _ in {1..25}; do
  if curl -fsS "${BACKEND_URL}/backend/health" >/dev/null 2>&1; then
    backend_up="1"
    break
  fi
  sleep 1
done

if [[ "$backend_up" != "1" ]]; then
  echo "   FAIL: backend did not become healthy."
  echo "   Check logs_backend.txt"
  exit 1
fi
echo "   PASS: backend healthy"

echo "3) Reading alert debug status..."
debug_json="$(curl -fsS "${BACKEND_URL}/alert/debug-status")"
python3 - <<'PY' "${debug_json}"
import json
import sys

data = json.loads(sys.argv[1])
fcm = data.get("fcm") or {}

print(f"   FCM ready: {fcm.get('ready')}")
print(f"   .env token count: {fcm.get('device_tokens_count')}")
print(f"   registered token count: {fcm.get('registered_tokens_count')}")
print(f"   topic: {fcm.get('topic')}")
issues = fcm.get("issues") or []
if issues:
    print("   FCM issues:")
    for issue in issues:
        print(f"   - {issue}")
PY

echo "4) Sending dispatch smoke test..."
test_message="Polaris verify $(date +%s)"
dispatch_json="$(curl -fsS -X POST "${BACKEND_URL}/alert/dispatch" \
  -H "Content-Type: application/json" \
  -d "{\"title\":\"Polaris Verify\",\"message\":\"${test_message}\",\"severity\":\"ADVISORY\",\"channel\":\"APP_NOTIFICATION\",\"source\":\"VERIFY_SCRIPT\"}")"

python3 - <<'PY' "${dispatch_json}"
import json
import sys

data = json.loads(sys.argv[1])
delivery = data.get("delivery") or {}
ok = bool(delivery.get("ok"))

print(f"   status: {data.get('status')}")
print(f"   delivery ok: {ok}")
print(f"   provider: {delivery.get('provider')}")

fcm = (delivery.get("results") or {}).get("fcm") or {}
if fcm:
    ts = fcm.get("token_sources") or {}
    if ts:
        print(
            "   token sources: "
            f"env={ts.get('env_count', 0)} "
            f"registered={ts.get('registered_count', 0)} "
            f"merged={ts.get('merged_count', 0)}"
        )

results = fcm.get("results") or []
if results:
    first = results[0]
    print(f"   first target: {first.get('target')}")
    print(f"   first target ok: {first.get('ok')}")
    if not first.get("ok"):
        print(f"   first target error: {first.get('resp') or first.get('error')}")

if not ok:
    raise SystemExit(1)
PY

echo "5) PASS: notification pipeline is working from backend side."
echo "   If phone still shows nothing, open app on phone once and allow notifications."
