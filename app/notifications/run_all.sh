#!/bin/zsh
set -e

echo "🚀 Starting Polaris system..."

cd ~/Desktop/Polaris || exit 1
source .venv/bin/activate

# Check Docker is running
if ! docker info >/dev/null 2>&1; then
  echo "❌ Docker daemon not running. Open Docker Desktop and try again."
  exit 1
fi

# Start Valkey (create if missing)
if docker ps -a --format '{{.Names}}' | grep -q '^polaris-valkey$'; then
  if docker ps --format '{{.Names}}' | grep -q '^polaris-valkey$'; then
    echo "✅ Valkey already running."
  else
    echo "🔄 Starting Valkey..."
    docker start polaris-valkey
  fi
else
  echo "🔄 Creating + starting Valkey..."
  docker run -d \
    --name polaris-valkey \
    --platform linux/arm64 \
    -p 6379:6379 \
    valkey/valkey:latest
fi

# Free port 8000 if in use
if lsof -ti :8000 >/dev/null 2>&1; then
  echo "⚠️ Port 8000 in use. Killing it..."
  kill -9 $(lsof -ti :8000) >/dev/null 2>&1 || true
fi

echo "🧠 Starting FastAPI backend..."
uvicorn app.main:app --reload > logs_backend.txt 2>&1 &

echo "📡 Starting Valkey router..."
python3 -m app.notifications.valkey_router
