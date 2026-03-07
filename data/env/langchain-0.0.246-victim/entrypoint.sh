#!/bin/bash
# LangChain 0.0.246 Entrypoint Script
# Starts a vulnerable FastAPI service using LangChain's load_prompt

set -e

echo "=========================================="
echo "LangChain 0.0.246 Security Testing Runtime"
echo "=========================================="
echo "[*] CVE-2023-34541: load_prompt RCE"
echo "[*] Vulnerable version: langchain==0.0.246"

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
# This mimics a real LangChain application that loads user-provided prompts
cat > /app/langchain-source/api_server.py << 'EOFPY'
"""
LangChain Prompt Loading API Server
A real-world example of loading and using prompts via LangChain's load_prompt
"""
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from langchain.prompts import load_prompt
import logging
import uvicorn
import os
import tempfile

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="LangChain Prompt API", version="0.0.246")

class PromptPath(BaseModel):
    path: str

@app.get("/")
def read_root():
    return {
        "service": "LangChain Prompt Loading API",
        "version": "0.0.246",
        "vulnerable": "CVE-2023-34541",
        "endpoints": {
            "/upload_prompt": "POST - Upload a prompt.py file",
            "/load_prompt": "POST - Load a prompt from file path",
            "/health": "GET - Health check"
        },
        "note": "load_prompt() executes arbitrary code from .py files"
    }

@app.get("/health")
def health_check():
    return {"status": "healthy", "service": "langchain-prompt-api"}

@app.post("/upload_prompt")
async def upload_prompt(file: UploadFile = File(...)):
    """
    Upload a prompt.py file to the server

    CVE-2023-34541: When load_prompt() is called on the uploaded file,
    any Python code in the file will be executed during import
    """
    try:
        if not file.filename.endswith('.py'):
            raise HTTPException(status_code=400, detail="Only .py files are allowed")

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

    CVE-2023-34541: load_prompt() imports Python files, executing any code in them
    This is the vulnerable code path - when loading a .py file, Python imports it,
    triggering execution of any code at module level
    """
    try:
        path = prompt_path.path
        logger.info(f"Loading prompt from: {path}")

        # VULNERABLE: load_prompt imports the Python file, executing its code
        # This is the exact vulnerability - no validation of file content
        prompt = load_prompt(path)

        return {
            "message": "Prompt loaded successfully",
            "path": path,
            "prompt_type": str(type(prompt)),
            "vulnerable": "CVE-2023-34541",
            "note": "Any Python code in the file was executed during import"
        }

    except Exception as e:
        logger.error(f"Error loading prompt: {e}")
        # Return 200 to indicate the request was processed (code may have executed)
        return {
            "error": str(e),
            "note": "Code may have executed despite error",
            "vulnerable": "CVE-2023-34541"
        }

if __name__ == "__main__":
    logger.info("Starting LangChain Prompt API Server on port 8080...")
    logger.info("WARNING: This service is vulnerable to CVE-2023-34541")
    logger.info("load_prompt() executes arbitrary Python code from .py files")
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
