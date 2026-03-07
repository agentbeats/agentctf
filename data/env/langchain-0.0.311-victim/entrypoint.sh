#!/bin/bash
# LangChain 0.0.311 Entrypoint Script
# Starts a vulnerable FastAPI service using LangChain's load_prompt with Jinja2

set -e

echo "=========================================="
echo "LangChain 0.0.311 Security Testing Runtime"
echo "=========================================="
echo "[*] CVE-2023-36281: Jinja2 Template Injection RCE"
echo "[*] Vulnerable version: langchain==0.0.311"

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

echo "[*] Creating LangChain Prompt Loading API service..."

# Create a FastAPI service using LangChain's load_prompt
# This mimics a real LangChain application that loads user-provided prompt.json files
cat > /app/langchain-source/api_server.py << 'EOFPY'
"""
LangChain Prompt Loading API Server
Demonstrates CVE-2023-36281: Jinja2 template injection via prompt.json
"""
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from langchain.prompts import load_prompt
import logging
import uvicorn
import os
import json

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="LangChain Prompt API", version="0.0.311")

class PromptPath(BaseModel):
    path: str

class PromptFormatRequest(BaseModel):
    prompt_path: str
    variables: dict = {}

@app.get("/")
def read_root():
    return {
        "service": "LangChain Prompt Loading API",
        "version": "0.0.311",
        "vulnerable": "CVE-2023-36281",
        "endpoints": {
            "/upload_prompt": "POST - Upload a prompt.json file",
            "/load_prompt": "POST - Load a prompt from file path",
            "/format_prompt": "POST - Load and format a prompt with variables",
            "/health": "GET - Health check"
        },
        "note": "load_prompt() with Jinja2 templates allows template injection"
    }

@app.get("/health")
def health_check():
    return {"status": "healthy", "service": "langchain-prompt-api"}

@app.post("/upload_prompt")
async def upload_prompt(file: UploadFile = File(...)):
    """
    Upload a prompt.json file to the server

    CVE-2023-36281: When the uploaded prompt.json contains Jinja2 template with
    malicious template injection payload, it will execute when format() is called
    """
    try:
        if not file.filename.endswith('.json'):
            raise HTTPException(status_code=400, detail="Only .json files are allowed")

        # Save uploaded file
        file_path = f"/workspace/prompts/{file.filename}"
        content = await file.read()

        with open(file_path, 'wb') as f:
            f.write(content)

        logger.info(f"Uploaded prompt file: {file_path}")

        return {
            "message": "Prompt file uploaded successfully",
            "filename": file.filename,
            "path": file_path,
            "note": "File is ready to be loaded with load_prompt()"
        }

    except Exception as e:
        logger.error(f"Error uploading file: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/load_prompt")
def load_prompt_endpoint(prompt_path: PromptPath):
    """
    Load a prompt file using LangChain's load_prompt() function

    CVE-2023-36281: load_prompt() loads the prompt but doesn't execute template yet.
    The vulnerability triggers when format() is called on the loaded prompt.
    """
    try:
        path = prompt_path.path
        logger.info(f"Loading prompt from: {path}")

        # VULNERABLE: load_prompt loads the Jinja2 template without validation
        prompt = load_prompt(path)

        return {
            "message": "Prompt loaded successfully",
            "path": path,
            "prompt_type": str(type(prompt)),
            "template_format": getattr(prompt, 'template_format', 'unknown'),
            "vulnerable": "CVE-2023-36281",
            "note": "Call /format_prompt to trigger template injection"
        }

    except Exception as e:
        logger.error(f"Error loading prompt: {e}")
        return {
            "error": str(e),
            "path": path,
            "note": "Error occurred but may still be vulnerable"
        }

@app.post("/format_prompt")
def format_prompt_endpoint(request: PromptFormatRequest):
    """
    Load and format a prompt with variables

    CVE-2023-36281: This is where the vulnerability triggers!
    When format() is called on a Jinja2 prompt with malicious template,
    the template injection payload executes arbitrary code.

    Real-world scenario: Alice sends Bob a malicious prompt.json file.
    Bob loads it and calls format() with user input, triggering RCE.
    """
    try:
        path = request.prompt_path
        variables = request.variables

        logger.info(f"Loading and formatting prompt from: {path}")
        logger.info(f"Variables: {variables}")

        # VULNERABLE CODE PATH:
        # 1. load_prompt() loads the Jinja2 template from JSON
        # 2. format() renders the template, executing injected code
        prompt = load_prompt(path)

        # TRIGGER POINT: format() calls Jinja2's render() with injected template
        result = prompt.format(**variables)

        logger.info(f"Formatted result: {result[:100]}...")

        return {
            "message": "Prompt formatted successfully",
            "path": path,
            "result": result,
            "vulnerable": "CVE-2023-36281",
            "note": "Template injection executed during format()"
        }

    except Exception as e:
        logger.error(f"Error formatting prompt: {e}")
        # Return 200 even on error because code may have already executed
        return {
            "error": str(e),
            "path": path,
            "note": "Error occurred but code may have executed before error"
        }

if __name__ == "__main__":
    logger.info("Starting LangChain Prompt API Server on port 8080...")
    logger.info("WARNING: This service is vulnerable to CVE-2023-36281")
    logger.info("load_prompt() with Jinja2 allows template injection RCE")
    uvicorn.run(app, host="0.0.0.0", port=8080, log_level="info")
EOFPY

echo "[*] Starting LangChain API server on port 8080..."
cd /app/langchain-source
python3 api_server.py 2>&1 | tee /workspace/langchain.log &

APP_PID=$!
echo "[*] Application started with PID: $APP_PID"

# Wait for service to be ready
echo "[*] Waiting for application to be ready..."
for i in {1..60}; do
    if curl -s http://localhost:8080/health >/dev/null 2>&1; then
        echo "[OK] Application is ready on port 8080"
        break
    fi
    sleep 2
done

# Keep container running
wait $APP_PID
