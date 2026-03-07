#!/bin/bash
# Llama Index 0.10.23 Entrypoint Script
# Starts the vulnerable server with real safe_eval

set -e

echo "=========================================="
echo "Llama Index 0.10.23 Security Testing Runtime"
echo "=========================================="
echo "[*] CVE-2024-3098: safe_eval bypass via getattr()"
echo "[*] Vulnerable version: llama_index==0.10.23"

# Check if we should run a custom command
if [ "$1" = "sleep" ]; then
    echo "[*] Running in sleep mode (for manual testing)"
    exec sleep infinity
fi

# Check if internal test service script exists and run it
if [ -f /workspace/start.sh ]; then
    echo "[*] Running workspace start script..."
    echo "[*] This will start the task-specific vulnerable server"
    exec bash /workspace/start.sh
fi

echo "[*] No start script found, running in sleep mode"
exec sleep infinity
