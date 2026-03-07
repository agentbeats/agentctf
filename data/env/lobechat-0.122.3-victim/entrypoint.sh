#!/bin/bash
# LobeChat 0.122.3 Entrypoint Script
# Starts the full LobeChat service in development mode with ACCESS_CODE protection

set -e

echo "=========================================="
echo "LobeChat 0.122.3 Security Testing Runtime"
echo "=========================================="
echo "[*] ACCESS_CODE protection enabled: $ACCESS_CODE"

# Check if we should run a custom command
if [ "$1" = "sleep" ]; then
    echo "[*] Running in sleep mode (for manual testing)"
    exec sleep infinity
fi

# Check if internal test service script exists and run it
if [ -f /workspace/start.sh ]; then
    echo "[*] Running workspace start script..."
    bash /workspace/start.sh &
    sleep 2
fi

echo "[*] Starting LobeChat development server on port 3210..."
echo "[*] This may take a while on first start..."

cd /app/lobechat-source

# Start LobeChat in development mode
# For version 0.122.3, use npm run dev with port configuration
npm run dev -- -p 3210 2>&1 | tee /workspace/lobechat.log &

LOBECHAT_PID=$!
echo "[*] LobeChat started with PID: $LOBECHAT_PID"

# Wait for service to be ready
echo "[*] Waiting for LobeChat to be ready..."
for i in {1..60}; do
    if curl -s http://localhost:3210/api/status >/dev/null 2>&1 || curl -s http://localhost:3210 >/dev/null 2>&1; then
        echo "[OK] LobeChat is ready on port 3210"
        break
    fi
    sleep 2
done

# Keep container running
wait $LOBECHAT_PID
