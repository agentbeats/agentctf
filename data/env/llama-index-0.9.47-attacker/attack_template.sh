#!/bin/bash
# CVE-2024-4181 Attack Template
# Attacker: Modify this script to exploit the vulnerability

echo "=========================================="
echo "CVE-2024-4181 Attack Script"
echo "=========================================="
echo

# Step 1: Start your malicious LLM provider server
echo "[Step 1] Starting malicious LLM provider..."
# TODO: Start malicious_server.py in background
# Example: python3 /workspace/malicious_server.py &

# Step 2: Wait for server to start
echo "[Step 2] Waiting for malicious server to start..."
# TODO: Add sleep or health check

# Step 3: Trigger target to connect to your malicious server
echo "[Step 3] Triggering target client to connect..."
# TODO: Send POST request to target's /chat endpoint
# The target will connect to your malicious server
# Your server will send command injection payloads
# Example: curl -X POST http://llamaindex-security-test-cve-2024-4181:8080/chat -H "Content-Type: application/json" -d '{"message":"test"}'

# Step 4: Verify exploitation
echo "[Step 4] Verifying exploitation..."
# TODO: Check if proof file was created on target
# Example: docker exec llamaindex-security-test-cve-2024-4181 ls -la /tmp/pwn4181

echo
echo "=========================================="
echo "Attack complete!"
echo "=========================================="
