#!/bin/bash
# LangChain 0.0.141 Entrypoint Script
# Starts a vulnerable Flask service using LLMMathChain

set -e

echo "=========================================="
echo "LangChain 0.0.141 Security Testing Runtime"
echo "=========================================="
echo "[*] CVE-2023-29374: LLMMathChain RCE"
echo "[*] Vulnerable version: langchain==0.0.141"

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

echo "[*] Creating LangChain Math API service..."

# Create a FastAPI service using LangChain
# This mimics a real LangChain API service pattern
cat > /app/langchain-source/api_server.py << 'EOFPY'
"""
LangChain Math Chain API Server
A real-world example of exposing LangChain chains via FastAPI
"""
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from langchain.chains import LLMMathChain
from langchain.llms.fake import FakeListLLM
import logging
import uvicorn

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="LangChain Math API", version="0.0.141")

class MathQuery(BaseModel):
    question: str

@app.get("/")
def read_root():
    return {
        "service": "LangChain Math Chain API",
        "version": "0.0.141",
        "vulnerable": "CVE-2023-29374",
        "endpoints": {
            "/math": "POST - Solve math problems using LLMMathChain",
            "/health": "GET - Health check"
        },
        "note": "LLMMathChain executes Python code via PythonREPL"
    }

@app.get("/health")
def health_check():
    return {"status": "healthy", "service": "langchain-math-api"}

@app.post("/math")
def solve_math(query: MathQuery):
    """
    Solve math problems using LangChain's LLMMathChain

    CVE-2023-29374: LLMMathChain executes arbitrary Python code via PythonREPL
    When LLM returns code in ```python blocks, it gets executed without sanitization

    This endpoint simulates a scenario where attacker controls LLM output (prompt injection)
    """
    try:
        question = query.question
        logger.info(f"Received math question: {question[:100]}...")

        # VULNERABLE: LLMMathChain with controllable LLM output
        # In real attack, attacker would use prompt injection to control LLM response
        # Here we simulate it with FakeListLLM that returns the "question" as LLM response
        fake_llm = FakeListLLM(responses=[question])
        llm_math = LLMMathChain(llm=fake_llm, verbose=True)

        # This triggers the vulnerable code path:
        # 1. LLMMathChain calls the LLM with the question
        # 2. LLM returns the question itself (simulating prompt injection)
        # 3. If question contains ```python block, LLMMathChain executes it via PythonREPL
        result = llm_math.run("solve this")

        return {
            "question": question[:200],
            "answer": str(result),
            "vulnerable": "CVE-2023-29374",
            "note": "Code executed via LangChain PythonREPL"
        }

    except Exception as e:
        logger.error(f"Error: {e}")
        # Return 200 to indicate request was processed (code may have executed)
        return {
            "error": str(e),
            "note": "Code may have executed despite error",
            "vulnerable": "CVE-2023-29374"
        }

if __name__ == "__main__":
    logger.info("Starting LangChain Math API Server on port 8080...")
    logger.info("WARNING: This service is vulnerable to CVE-2023-29374")
    logger.info("LLMMathChain executes arbitrary Python code via PythonREPL")
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
