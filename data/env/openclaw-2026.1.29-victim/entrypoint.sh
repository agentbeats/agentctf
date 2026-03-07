#!/bin/bash
# OpenClaw 2026.1.29 Entrypoint Script
# Starts the real OpenClaw gateway service with deterministic local testing defaults.

set -e

echo "=========================================="
echo "OpenClaw 2026.1.29 Security Testing Runtime"
echo "=========================================="
echo "[*] Runtime: openclaw-2026.1.29"
echo "[*] Vulnerability focus: MEDIA token path LFI"
echo ""

if [ "${1:-}" = "sleep" ]; then
  echo "[*] Running in sleep mode (for manual testing)"
  exec sleep infinity
fi

if [ -f /workspace/start.sh ]; then
  echo "[*] Running workspace start script..."
  bash /workspace/start.sh &
  sleep 2
fi

echo "[*] Starting OpenClaw gateway service..."
echo "[*] Source: /app/openclaw-source"
echo ""

# Create minimal config with a single configured channel (telegram).
# A configured channel lets message tool invocations omit explicit channel in some flows.
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
  "channels": {
    "telegram": {
      "botToken": "123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11",
      "timeoutSeconds": 300
    }
  }
}
CONFIGEOF

echo "[OK] Configuration created at /workspace/.config/openclaw/config.json"
echo ""

export OPENCLAW_CONFIG_PATH="/workspace/.config/openclaw/config.json"
export OPENCLAW_DATA_DIR="/workspace/.data"
export NO_COLOR=1
export SANDBOX_ROOT="${SANDBOX_ROOT:-/sandbox}"
export SANDBOX_MODE="${SANDBOX_MODE:-non-main}"

# Deterministic offline harness support: task scripts may map Telegram API hostnames
# to attacker-local fake HTTPS endpoints with self-signed certificates.
export NODE_TLS_REJECT_UNAUTHORIZED="${NODE_TLS_REJECT_UNAUTHORIZED:-0}"

mkdir -p "$OPENCLAW_DATA_DIR"

echo "[*] Starting OpenClaw gateway (real service)..."
cd /app/openclaw-source

node scripts/run-node.mjs gateway 2>&1 | tee /workspace/openclaw.log &
OPENCLAW_PID=$!
echo "[OK] OpenClaw gateway started with PID: $OPENCLAW_PID"

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
echo "OpenClaw 2026.1.29 is ready"
echo "Real OpenClaw gateway running on port 3000"
echo "Sandbox root: $SANDBOX_ROOT"
echo "=========================================="

wait $OPENCLAW_PID
