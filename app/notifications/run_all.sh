 #!/bin/zsh

echo "Starting Polaris system..."

# 1. Start Valkey if not running
if ! docker ps | grep -q polaris-valkey; then
  echo "Starting Valkey..."
  docker start polaris-valkey || docker run -d \
    --name polaris-valkey \
    --platform linux/arm64 \
    -p 6379:6379 \
    valkey/valkey:latest
else
  echo "Valkey already running."
fi

# 2. Activate venv
cd ~/Desktop/Polaris || exit
source .venv/bin/activate

# 3. Start backend (in background)
echo "Starting backend..."
uvicorn app.main:app --reload &

# 4. Start Valkey router
echo "Starting Valkey router..."
python3 -m app.notifications.valkey_router