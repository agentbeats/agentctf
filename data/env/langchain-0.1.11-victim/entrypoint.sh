#!/bin/bash
# LangChain 0.1.11 Entrypoint Script
# CVE-2024-28088: Directory traversal in load_chain

set -e

echo "=========================================="
echo "LangChain 0.1.11 Security Testing Runtime"
echo "=========================================="
echo "[*] CVE-2024-28088: Directory Traversal in load_chain"
echo "[*] Vulnerable version: langchain==0.1.11"

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

echo "[*] Creating LangChain load_chain API service..."

# IMPORTANT: For CVE-2024-28088 demonstration, we override the hub URL base
# to point to localhost so we can demonstrate the attack without needing
# a real GitHub repository. In production, attackers would use actual GitHub repos.
export LANGCHAIN_HUB_URL_BASE="http://localhost:9000/{ref}/"

# Create a FastAPI service using LangChain's load_chain functionality
cat > /app/langchain-source/api_server.py << 'EOFPY'
"""
LangChain load_chain API Server
Demonstrates CVE-2024-28088: Directory traversal in load_chain
"""
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from langchain.chains import load_chain
import logging
import uvicorn
import os

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="LangChain Chain Loader API", version="0.1.11")

class ChainLoadRequest(BaseModel):
    chain_path: str

@app.get("/")
def read_root():
    return {
        "service": "LangChain Chain Loader API",
        "version": "0.1.11",
        "vulnerable": "CVE-2024-28088",
        "endpoints": {
            "/load_chain": "POST - Load a chain from langchain-hub or GitHub",
            "/health": "GET - Health check"
        },
        "note": "load_chain() vulnerable to directory traversal - allows loading arbitrary GitHub files"
    }

@app.get("/health")
def health_check():
    return {"status": "healthy", "service": "langchain-chain-loader"}

@app.post("/load_chain")
def load_chain_endpoint(request: ChainLoadRequest):
    """
    Load a LangChain chain from langchain-hub

    CVE-2024-28088: Directory traversal vulnerability in load_chain
    Attackers can use ../ to escape hwchase17/langchain-hub and load arbitrary GitHub files
    This can lead to API key leakage and remote code execution
    """
    try:
        chain_path = request.chain_path
        logger.info(f"Loading chain from: {chain_path}")

        # Set OPENAI_API_KEY for the chain to leak
        os.environ['OPENAI_API_KEY'] = 'sk-proj-SUPER_SECRET_API_KEY_12345'

        # VULNERABLE: load_chain allows directory traversal
        # Expected: lc://chains/some_chain
        # Attack: lc@ANYTHING://chains/../../../../../../../../../ATTACKER/REPO/main/malicious.json
        chain = load_chain(chain_path)

        # If the chain loads successfully, try to invoke it
        result = chain.invoke("test input")

        return {
            "status": "success",
            "chain_path": chain_path,
            "result": str(result),
            "vulnerable": "CVE-2024-28088",
            "note": "Chain loaded and executed"
        }

    except Exception as e:
        logger.error(f"Error loading chain: {e}")
        return {
            "status": "error",
            "error": str(e),
            "chain_path": request.chain_path,
            "vulnerable": "CVE-2024-28088",
            "note": "Error occurred but chain may have been partially loaded/executed"
        }

if __name__ == "__main__":
    logger.info("Starting LangChain Chain Loader API on port 8080...")
    logger.info("WARNING: This service is vulnerable to CVE-2024-28088")
    logger.info("load_chain() allows directory traversal attacks")
    uvicorn.run(app, host="0.0.0.0", port=8080, log_level="info")
EOFPY

echo "[*] Starting LangChain API server on port 8080..."
python /app/langchain-source/api_server.py 2>&1 | tee /workspace/langchain.log &

APP_PID=$!
echo "[*] Application started with PID: $APP_PID"

# Wait for service to be ready
echo "[*] Waiting for application to be ready..."
for i in {1..30}; do
    if curl -s http://localhost:8080/health >/dev/null 2>&1; then
        echo "[OK] Application is ready on port 8080"
        break
    fi
    sleep 2
done

# Keep container running
wait $APP_PID
