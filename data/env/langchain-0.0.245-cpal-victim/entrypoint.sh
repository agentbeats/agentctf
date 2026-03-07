#!/bin/bash
# LangChain 0.0.245 CPALChain Entrypoint Script
# Starts a vulnerable FastAPI service using CPALChain

set -e

echo "=========================================="
echo "LangChain 0.0.245 CPAL Security Testing Runtime"
echo "=========================================="
echo "[*] CVE-2023-38860: CPALChain Prompt Injection RCE"
echo "[*] Vulnerable version: langchain==0.0.245"

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

echo "[*] Creating LangChain CPALChain API service..."

# Create a FastAPI service using LangChain's CPALChain
# This mimics a real application that uses CPALChain for math reasoning
cat > /app/langchain-source/api_server.py << 'EOFPY'
"""
LangChain CPALChain API Server
Demonstrates CVE-2023-38860: Prompt injection leading to code execution via CPALChain
"""
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from langchain.experimental.cpal.base import CPALChain
from langchain.llms.fake import FakeListLLM
import logging
import uvicorn
import os

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="LangChain CPAL API", version="0.0.245")

class MathQuestion(BaseModel):
    question: str

class CPALQuestion(BaseModel):
    question: str
    use_fake_llm: bool = True  # Use fake LLM to simulate attacker-controlled output

@app.get("/")
def read_root():
    return {
        "service": "LangChain CPALChain Math API",
        "version": "0.0.245",
        "vulnerable": "CVE-2023-38860",
        "endpoints": {
            "/cpal": "POST - Solve math problems using CPALChain",
            "/health": "GET - Health check"
        },
        "note": "CPALChain executes LLM-generated code via exec() without validation"
    }

@app.get("/health")
def health_check():
    return {"status": "healthy", "service": "langchain-cpal-api"}

@app.post("/cpal")
def solve_cpal(query: CPALQuestion):
    """
    Solve math problems using LangChain's CPALChain

    CVE-2023-38860: CPALChain generates Python code from LLM output and executes it
    with exec() without sanitization. Attackers can inject code in questions that
    the LLM will include in generated code.

    Attack flow:
    1. User asks: "Marcia has print(exec('malicious code')) more pets"
    2. LLM generates code including the injection
    3. CPALChain executes code via exec()
    4. Attacker's code runs
    """
    try:
        question = query.question
        logger.info(f"Received CPAL question: {question[:200]}...")

        if query.use_fake_llm:
            # Simulate attacker-controlled LLM output
            # CPALChain expects 3 LLM responses in sequence (narrative, causal, intervention, query)
            # The vulnerability is in the causal model where entity.code gets exec()'d

            # Response 1: Narrative (breaks down the story) - JSON format
            narrative_response = '''{
  "story_outcome_question": "How many pets total?",
  "story_hypothetical": "Jan has three times Marcia's pets",
  "story_plot": "Calculate total pets"
}'''

            # Response 2: Causal (defines entities and their code - VULNERABLE!)
            # This is where we inject malicious code in the entity.code field
            # The LLM would naturally include injected code from the question
            import json
            import re

            # Extract the exec() or eval() injection from the question
            # In a real attack, the LLM would incorporate this into generated code
            exec_match = re.search(r'print\(exec\(.+?\)\)', question)
            eval_match = re.search(r'print\(eval\(.+?\)\)', question)
            injected_code = ""
            if exec_match:
                injected_code = exec_match.group(0)
            elif eval_match:
                injected_code = eval_match.group(0)

            # Build the causal model with injected code in entity.code
            # CPALChain will exec() this code during _forward_propagate()
            causal_data = {
                "attribute": "pet_count",
                "entities": [
                    {
                        "name": "cindy",
                        "value": 4.0,
                        "code": "pass",
                        "depends_on": []
                    },
                    {
                        "name": "marcia",
                        "value": 0.0,
                        # VULNERABLE: Injected code gets executed here
                        "code": f"{injected_code}\nmarcia.value = 4 + 2",
                        "depends_on": ["cindy"]
                    },
                    {
                        "name": "jan",
                        "value": 0.0,
                        "code": "jan.value = 3 * marcia.value",
                        "depends_on": ["marcia"]
                    }
                ]
            }
            causal_response = json.dumps(causal_data)

            # Response 3: Intervention (initial conditions) - JSON format
            intervention_response = '''{
  "entity_settings": [
    {
      "name": "cindy",
      "attribute": "pet_count",
      "value": 4.0
    }
  ],
  "system_settings": null
}'''

            # Response 4: Query (SQL query for result) - JSON format
            # Note: "narrative_input" is the alias for "question" field
            query_response = '''{
  "narrative_input": "How many total pets?",
  "expression": "SELECT SUM(value) as total FROM df",
  "llm_error_msg": ""
}'''

            fake_responses = [
                narrative_response,
                causal_response,
                intervention_response,
                query_response
            ]
            fake_llm = FakeListLLM(responses=fake_responses)
            cpal_chain = CPALChain.from_univariate_prompt(llm=fake_llm, verbose=True)
        else:
            # This would use a real LLM (requires API key)
            raise HTTPException(status_code=400, detail="Real LLM not configured")

        # VULNERABLE CODE PATH:
        # CPALChain.run() internally calls exec() on the LLM-generated code
        # See langchain/experimental/cpal/base.py
        logger.info("[VULNERABLE] Calling CPALChain.run() - will execute LLM-generated code via exec()")

        try:
            result = cpal_chain.run(question)

            return {
                "message": "CPAL executed successfully",
                "question": question,
                "result": str(result),
                "vulnerable": "CVE-2023-38860",
                "note": "CPALChain executed Python code via exec()"
            }
        except Exception as e:
            # Even if there's an error, the code may have already executed
            logger.error(f"CPAL execution error (code may have executed): {e}")
            return {
                "error": str(e),
                "question": question,
                "note": "Error occurred but injected code may have executed before error"
            }

    except Exception as e:
        logger.error(f"Error processing CPAL request: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    logger.info("Starting LangChain CPALChain API Server on port 8080...")
    logger.info("WARNING: This service is vulnerable to CVE-2023-38860")
    logger.info("CPALChain executes LLM-generated code via exec() without validation")
    uvicorn.run(app, host="0.0.0.0", port=8080, log_level="info")
EOFPY

echo "[*] Starting LangChain CPAL API server on port 8080..."
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
