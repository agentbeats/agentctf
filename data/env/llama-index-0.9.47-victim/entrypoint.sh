#!/bin/bash
# Entrypoint for llama_index 0.9.47 test environment
# CVE-2024-4181: Command injection via compromised LLM provider

set -e

echo "=========================================="
echo "llama_index 0.9.47 Test Environment"
echo "CVE-2024-4181 - Command Injection via RunGptLLM"
echo "=========================================="
echo

echo "[*] Container: llamaindex-security-test-${TASK_ID}"
echo "[*] Working directory: /workspace"
echo "[*] Source code: /app/llama-index-source"
echo

# Keep container running
exec "$@"
