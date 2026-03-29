#!/bin/zsh
set -e

echo "🚀 Starting Polaris system..."

cd ~/Desktop/Polaris || exit 1
source .venv/bin/activate

# Valkey is optional now (auto alert dispatch runs directly in app.main).
if docker info >/dev/null 2>&1; then
  if docker ps -a --format '{{.Names}}' | grep -q '^polaris-valkey$'; then
    if docker ps --format '{{.Names}}' | grep -q '^polaris-valkey$'; then
      echo "✅ Valkey already running (optional)."
    else
      echo "🔄 Starting Valkey (optional)..."
      docker start polaris-valkey >/dev/null 2>&1 || true
    fi
  else
    echo "🔄 Creating + starting Valkey (optional)..."
    docker run -d \
      --name polaris-valkey \
      --platform linux/arm64 \
      -p 6379:6379 \
      valkey/valkey:latest >/dev/null 2>&1 || true
  fi
else
  echo "⚠️ Docker/Valkey not running. Continuing (optional dependency)."
fi

# Free port 8000 if in use
if lsof -ti :8000 >/dev/null 2>&1; then
  echo "⚠️ Port 8000 in use. Killing it..."
  kill -9 $(lsof -ti :8000) >/dev/null 2>&1 || true
fi

echo "🧠 Starting FastAPI backend..."
uvicorn_args=("app.main:app")
api_host="${POLARIS_API_HOST:-0.0.0.0}"
api_port="${POLARIS_API_PORT:-8000}"
uvicorn_args+=("--host" "$api_host" "--port" "$api_port")
if [[ "${POLARIS_UVICORN_RELOAD:-0}" == "1" ]]; then
  echo "ℹ️ POLARIS_UVICORN_RELOAD=1 -> starting with --reload"
  uvicorn_args+=("--reload")
fi
uvicorn "${uvicorn_args[@]}" > logs_backend.txt 2>&1 &
echo "✅ Backend started. Auto alert dispatch is handled inside app.main."
