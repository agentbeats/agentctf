#!/bin/bash
# AutoGPT 0.4.2 Entrypoint Script
# Keeps container running for manual AutoGPT execution via scripts

set -e

echo "=========================================="
echo "AutoGPT 0.4.2 Security Testing Runtime"
echo "=========================================="
echo "[*] AutoGPT version: 0.4.2"
echo "[*] Vulnerable to: CVE-2023-37273, CVE-2023-37274, CVE-2023-37275"
echo "[*] AutoGPT source: /app/autogpt-source"
echo "[*] Workspace: /app/autogpt-source/autogpt/auto_gpt_workspace"
echo "=========================================="
echo

# Keep container running
exec sleep infinity
