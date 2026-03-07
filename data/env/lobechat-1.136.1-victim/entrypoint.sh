#!/bin/bash
# LobeChat 1.136.1 Entrypoint Script
# Starts the full LobeChat service in development mode

set -e

echo "=========================================="
echo "LobeChat 1.136.1 Security Testing Runtime"
echo "=========================================="

# Check if we should run a custom command
if [ "$1" = "sleep" ]; then
    echo "[*] Running in sleep mode (for manual testing)"
    exec sleep infinity
fi

# Check if internal test service script exists and run it
if [ -f /workspace/internal_service.sh ]; then
    echo "[*] Starting internal test service..."
    bash /workspace/internal_service.sh &
    sleep 2
fi

echo "[*] Starting LobeChat development server on port 3010..."
echo "[*] This may take a while on first start..."

cd /app/lobechat-source

# Start LobeChat in development mode with turbopack
# Note: package.json dev script already includes -p 3010, don't pass it again
if command -v pnpm &> /dev/null; then
    pnpm dev 2>&1 | tee /workspace/lobechat.log &
else
    npm run dev 2>&1 | tee /workspace/lobechat.log &
fi

LOBECHAT_PID=$!
echo "[*] LobeChat started with PID: $LOBECHAT_PID"

# Wait for service to be ready
echo "[*] Waiting for LobeChat to be ready..."
for i in {1..60}; do
    if curl -s http://localhost:3010 >/dev/null 2>&1; then
        echo "[OK] LobeChat is ready on port 3010"
        break
    fi
    sleep 2
done

# Keep container running
wait $LOBECHAT_PID
