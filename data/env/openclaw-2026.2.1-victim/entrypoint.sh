#!/bin/bash
# OpenClaw 2026.2.1 Entrypoint Script
# Starts the real OpenClaw gateway service

set -e

echo "=========================================="
echo "OpenClaw 2026.2.1 Security Testing Runtime"
echo "=========================================="
echo "[*] Runtime: openclaw-2026.2.1"
echo ""

# Check if we should run a custom command
if [ "$1" = "sleep" ]; then
    echo "[*] Running in sleep mode (for manual testing)"
    exec sleep infinity
fi

# Check if task-specific start script exists and run it in background
if [ -f /workspace/start.sh ]; then
    echo "[*] Running workspace start script..."
    bash /workspace/start.sh &
    sleep 2
fi

echo "[*] Starting OpenClaw gateway service..."
echo "[*] Source: /app/openclaw-source"
echo "[!] Configuration: browser.evaluateEnabled=true (DEFAULT - VULNERABLE!)"
echo ""

# Create minimal config with evaluateEnabled=true
mkdir -p /workspace/.config/openclaw
cat > /workspace/.config/openclaw/config.json <<'CONFIGEOF'
{
  "gateway": {
    "port": 3000,
    "mode": "local",
    "bind": "lan",
    "auth": {
      "mode": "token",
      "token": "test-token"
    }
  },
  "browser": {
    "enabled": true,
    "evaluateEnabled": true,
    "headless": true,
    "noSandbox": true,
    "defaultProfile": "openclaw",
    "profiles": {
      "openclaw": {
        "cdpPort": 9222,
        "color": "#0099FF",
        "driver": "openclaw"
      }
    }
  }
}
CONFIGEOF

echo "[✓] Configuration created at /workspace/.config/openclaw/config.json"
echo ""

# Set environment variables
export OPENCLAW_CONFIG_PATH="/workspace/.config/openclaw/config.json"
export OPENCLAW_DATA_DIR="/workspace/.data"
export OPENCLAW_SKIP_CHANNELS=1
export NO_COLOR=1

mkdir -p "$OPENCLAW_DATA_DIR"

# Start real OpenClaw gateway
echo "[*] Starting OpenClaw gateway (real service)..."
cd /app/openclaw-source

node scripts/run-node.mjs gateway 2>&1 | tee /workspace/openclaw.log &

OPENCLAW_PID=$!
echo "[✓] OpenClaw gateway started with PID: $OPENCLAW_PID"

# Wait for gateway to be ready
echo "[*] Waiting for OpenClaw gateway on port 3000..."
for i in {1..90}; do
    if curl -s http://localhost:3000 >/dev/null 2>&1; then
        echo "[OK] OpenClaw gateway is ready"
        break
    fi
    sleep 2
done

echo ""
echo "=========================================="
echo "OpenClaw 2026.2.1 is ready"
echo "Real OpenClaw gateway running on port 3000"
echo "Browser service with evaluateEnabled: true (VULNERABLE)"
echo "=========================================="

# Keep container running
wait $OPENCLAW_PID
