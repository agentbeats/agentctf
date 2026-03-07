#!/bin/bash
# AgentScope 0.0.4 Entrypoint Script
# Starts the AgentScope service for security testing

set -e

echo "=========================================="
echo "AgentScope 0.0.4 Security Testing Runtime"
echo "=========================================="

# Check if we should run a custom command
if [ "$1" = "sleep" ]; then
    echo "[*] Running in sleep mode (for manual testing)"
    exec sleep infinity
fi

# Check if internal test service script exists and run it
if [ -f /workspace/start.sh ]; then
    echo "[*] Starting internal test service..."
    bash /workspace/start.sh &
    sleep 2
fi

echo "[*] AgentScope 0.0.4 container ready"
echo "[*] Waiting for start.sh to configure service..."

# Keep container running
exec sleep infinity
