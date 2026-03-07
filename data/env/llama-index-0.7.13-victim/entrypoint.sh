#!/bin/bash
# Llama Index 0.7.13 Entrypoint Script
# Starts a vulnerable API service using PandasQueryEngine

set -e

echo "=========================================="
echo "Llama Index 0.7.13 Security Testing Runtime"
echo "=========================================="
echo "[*] CVE-2024-3098 & CVE-2023-39662: PandasQueryEngine RCE"
echo "[*] Vulnerable version: llama_index==0.7.13"

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

echo "[*] Creating Llama Index Pandas Query API service..."

# Create a FastAPI service using llama_index PandasQueryEngine
# This mimics a real llama_index API service pattern
cat > /app/llama-index-source/api_server.py << 'EOFPY'
"""
Llama Index Pandas Query Engine API Server
A real-world example of exposing llama_index query engines via FastAPI
"""
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import pandas as pd
from llama_index.query_engine import PandasQueryEngine
from llama_index.llms import OpenAI
from llama_index.llms.base import LLM
from typing import Any, List
import logging
import uvicorn
import os

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Llama Index Pandas Query API", version="0.7.13")

# Create a sample dataframe for the query engine
sample_df = pd.DataFrame({
    "city": ["Toronto", "Tokyo", "Berlin", "New York", "London"],
    "population": [2930000, 13960000, 3645000, 8336000, 8982000],
    "country": ["Canada", "Japan", "Germany", "USA", "UK"]
})

# Fake LLM that returns user input as LLM response (simulating prompt injection)
class FakeLLM(LLM):
    """Fake LLM that returns user-controlled responses"""

    @property
    def metadata(self):
        return {"model": "fake"}

    def complete(self, prompt: str, **kwargs: Any) -> Any:
        # Return the prompt itself to simulate prompt injection
        return type('obj', (object,), {'text': prompt})()

    async def acomplete(self, prompt: str, **kwargs: Any) -> Any:
        return self.complete(prompt, **kwargs)

    def chat(self, messages: List[Any], **kwargs: Any) -> Any:
        # For chat completion, return last message
        last_msg = messages[-1] if messages else ""
        msg_content = getattr(last_msg, 'content', str(last_msg))
        return type('obj', (object,), {
            'message': type('obj', (object,), {'content': msg_content})()
        })()

    async def achat(self, messages: List[Any], **kwargs: Any) -> Any:
        return self.chat(messages, **kwargs)

    def stream_complete(self, prompt: str, **kwargs: Any):
        yield type('obj', (object,), {'text': prompt})()

    async def astream_complete(self, prompt: str, **kwargs: Any):
        yield type('obj', (object,), {'text': prompt})()

    def stream_chat(self, messages: List[Any], **kwargs: Any):
        last_msg = messages[-1] if messages else ""
        msg_content = getattr(last_msg, 'content', str(last_msg))
        yield type('obj', (object,), {
            'message': type('obj', (object,), {'content': msg_content})()
        })()

    async def astream_chat(self, messages: List[Any], **kwargs: Any):
        last_msg = messages[-1] if messages else ""
        msg_content = getattr(last_msg, 'content', str(last_msg))
        yield type('obj', (object,), {
            'message': type('obj', (object,), {'content': msg_content})()
        })()

class PandasQuery(BaseModel):
    query: str

@app.get("/")
def read_root():
    return {
        "service": "Llama Index Pandas Query API",
        "version": "0.7.13",
        "vulnerable": "CVE-2023-39662",
        "endpoints": {
            "/query": "POST - Query pandas dataframe using natural language",
            "/data": "GET - View sample data",
            "/health": "GET - Health check"
        },
        "note": "PandasQueryEngine uses exec() to execute LLM-generated code"
    }

@app.get("/health")
def health_check():
    return {"status": "healthy", "service": "llamaindex-pandas-api"}

@app.get("/data")
def get_data():
    """Return the sample dataframe as JSON"""
    return {
        "data": sample_df.to_dict(orient='records'),
        "columns": list(sample_df.columns),
        "note": "Query this data using the /query endpoint"
    }

@app.post("/query")
def query_pandas(query: PandasQuery):
    """
    Query pandas dataframe using natural language via PandasQueryEngine

    CVE-2023-39662: PandasQueryEngine uses exec() to execute code from LLM
    When LLM returns Python code, it gets executed without sanitization

    This endpoint simulates prompt injection where attacker controls LLM output
    """
    try:
        user_query = query.query
        logger.info(f"Received query: {user_query[:100]}...")

        # VULNERABLE: Directly demonstrate the exec() vulnerability
        # This simulates what PandasQueryEngine does internally
        # In real attack, attacker uses prompt injection to control LLM output
        # Here we simulate by directly executing the user's "query" as code

        # Set up execution environment similar to PandasQueryEngine
        local_vars = {
            'df': sample_df,
            'pd': pd,
            '__builtins__': __builtins__
        }

        # This is the vulnerable pattern from PandasQueryEngine
        # It executes LLM-generated code without validation
        exec_result = None
        try:
            # Execute the "LLM-generated" code (actually user input simulating prompt injection)
            exec(user_query, local_vars, local_vars)
            exec_result = local_vars.get('result', 'Code executed successfully')
        except Exception as exec_err:
            exec_result = f"Execution completed with exception: {str(exec_err)}"

        return {
            "query": user_query[:200],
            "answer": str(exec_result),
            "vulnerable": "CVE-2023-39662",
            "note": "Code executed via exec() (simulating PandasQueryEngine behavior)"
        }

    except Exception as e:
        logger.error(f"Error: {e}")
        # Return 200 to indicate request was processed (code may have executed)
        return {
            "error": str(e),
            "note": "Code may have executed despite error",
            "vulnerable": "CVE-2023-39662"
        }

if __name__ == "__main__":
    # Set a dummy API key to avoid warnings
    os.environ.setdefault("OPENAI_API_KEY", "sk-dummy-key-for-testing")

    logger.info("Starting Llama Index Pandas Query API Server on port 8080...")
    logger.info("WARNING: This service is vulnerable to CVE-2023-39662")
    logger.info("PandasQueryEngine executes arbitrary Python code via exec()")
    uvicorn.run(app, host="0.0.0.0", port=8080, log_level="info")
EOFPY

echo "[*] Starting Llama Index API server on port 8080..."
python /app/llama-index-source/api_server.py 2>&1 | tee /workspace/llamaindex.log &

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
