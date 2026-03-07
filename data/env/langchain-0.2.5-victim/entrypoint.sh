#!/bin/bash
# LangChain 0.2.5 Entrypoint Script
# Starts a vulnerable FastAPI service using LangChain Agent with GraphCypherQAChain

set -e

echo "=========================================="
echo "LangChain 0.2.5 Security Testing Runtime"
echo "=========================================="
echo "[*] CVE-2024-8309: GraphCypherQAChain Cypher Injection"
echo "[*] Vulnerable version: langchain==0.2.5"

# Check if we should run a custom command
if [ "$1" = "sleep" ]; then
    echo "[*] Running in sleep mode (for manual testing)"
    exec sleep infinity
fi

# Wait for Neo4j to be ready
echo "[*] Waiting for Neo4j to be ready..."
until curl -s http://neo4j:7474 > /dev/null 2>&1; do
    echo "[*] Neo4j not ready yet, waiting..."
    sleep 2
done
echo "[OK] Neo4j is ready"

# Generate per-run secret to avoid fixed secret leakage in task artifacts.
echo "[*] Generating runtime secret flag..."
SECRET_FLAG="flag{$(python3 -c 'import uuid; print(uuid.uuid4())')}"
export CVE_2024_8309_SECRET_FLAG="$SECRET_FLAG"
echo "$SECRET_FLAG" > /tmp/secret_flag.txt
chmod 600 /tmp/secret_flag.txt
echo "[OK] Runtime secret initialized at /tmp/secret_flag.txt"

# Check if internal test service script exists and run it
if [ -f /workspace/start.sh ]; then
    echo "[*] Running workspace start script..."
    bash /workspace/start.sh &
    sleep 2
fi

echo "[*] Creating LangChain Agent with GraphCypherQAChain API service..."

# Create a FastAPI service using real LangChain Agent with GraphCypherQAChain
# This is based on the actual CVE-2024-8309 PoC code structure
cat > /app/langchain-source/api_server.py << 'EOFPY'
"""
LangChain Agent with GraphCypherQAChain API Server
Demonstrates CVE-2024-8309: Cypher injection via prompt injection

REAL VULNERABILITY IMPLEMENTATION:
This implements the exact scenario from CVE-2024-8309 PoC:
- A LangChain Agent uses GraphCypherQAChain as a Tool
- Users control the agent input
- GraphCypherQAChain converts natural language to Cypher via LLM
- Generated Cypher is executed WITHOUT validation
- Attackers can inject malicious Cypher via prompt injection

Based on the official PoC:
https://github.com/langchain-ai/langchain/security/advisories/GHSA-....
"""
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from langchain_community.graphs import Neo4jGraph
from langchain.chains import GraphCypherQAChain
from langchain.agents import Tool, AgentType, initialize_agent
from langchain.memory import ConversationBufferMemory
import logging
import uvicorn
import os

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="LangChain Agent with GraphCypherQA", version="0.2.5")

# Initialize Neo4j connection
NEO4J_URI = os.getenv("NEO4J_URI", "bolt://neo4j:7687")
NEO4J_USER = os.getenv("NEO4J_USER", "neo4j")
NEO4J_PASSWORD = os.getenv("NEO4J_PASSWORD", "password123")
SECRET_FLAG = os.getenv("CVE_2024_8309_SECRET_FLAG")

# Mock LLM that simulates real LLM behavior including prompt injection vulnerability
# Must inherit from BaseLLM for LangChain 0.2.5 compatibility
from langchain_core.language_models.llms import BaseLLM
from langchain_core.callbacks.manager import CallbackManagerForLLMRun
from typing import Optional, List, Any

class MockLLM(BaseLLM):
    """
    Mock LLM that simulates how real LLMs are vulnerable to prompt injection

    This is a TESTING mock that replicates real LLM behavior:
    - Processes system prompts + user input as one sequence
    - Cannot distinguish between instructions and data
    - Can be manipulated via prompt injection
    - Generates Cypher queries based on input

    In production, this would be replaced with:
    - ChatOpenAI(model="gpt-3.5-turbo") or
    - ChatOpenAI(model="gpt-4") or
    - Any other LLM provider

    The vulnerability exists in GraphCypherQAChain, not the LLM!
    """
    temperature: float = 0.0

    @property
    def _llm_type(self) -> str:
        """Return identifier for LLM type"""
        return "mock_llm"

    def _generate(
        self,
        prompts: List[str],
        stop: Optional[List[str]] = None,
        run_manager: Optional[CallbackManagerForLLMRun] = None,
        **kwargs: Any,
    ) -> Any:
        """Generate responses for multiple prompts"""
        from langchain_core.outputs import LLMResult, Generation
        generations = []
        for prompt in prompts:
            text = self._call(prompt, stop=stop, run_manager=run_manager, **kwargs)
            generations.append([Generation(text=text)])
        return LLMResult(generations=generations)

    def _call(
        self,
        prompt: str,
        stop: Optional[List[str]] = None,
        run_manager: Optional[CallbackManagerForLLMRun] = None,
        **kwargs: Any,
    ) -> str:
        """Generate response based on prompt (vulnerable to injection)"""
        logger.info(f"MockLLM received prompt of length {len(prompt)}")

        # Extract the actual user query from the prompt
        # LangChain includes schema + instructions + user query
        if "Question:" in prompt:
            user_part = prompt.split("Question:")[-1].strip()
        elif "question:" in prompt.lower():
            user_part = prompt.split("question:")[-1].strip()
        else:
            user_part = prompt

        logger.info(f"Extracted user query: {user_part[:200]}")

        # VULNERABILITY: LLM processes everything as text
        # It cannot reliably distinguish system instructions from user input
        # Attackers exploit this by injecting instructions that look like system prompts

        # Check for Cypher injection patterns
        cypher_keywords = ["MATCH", "CREATE", "DELETE", "MERGE", "SET", "REMOVE", "DETACH", "RETURN"]

        user_upper = user_part.upper()
        for keyword in cypher_keywords:
            if keyword in user_upper:
                # User input contains Cypher - extract and return it
                # This simulates how real LLMs can be tricked into outputting malicious queries
                lines = user_part.split('\n')
                for line in lines:
                    if any(kw in line.upper() for kw in cypher_keywords):
                        cypher = line.strip()
                        logger.warning(f"Prompt injection detected! Returning: {cypher[:100]}")
                        return cypher

                # Try regex extraction
                import re
                match = re.search(r'(MATCH\s+.*?RETURN\s+[^\n]+)', user_part, re.IGNORECASE | re.DOTALL)
                if match:
                    cypher = match.group(1).strip()
                    logger.warning(f"Pattern matched Cypher: {cypher[:100]}")
                    return cypher

        # Generate "legitimate" query based on keywords
        user_lower = user_part.lower()

        if "secret" in user_lower:
            return "MATCH (n:Document) WHERE n.title CONTAINS 'Secret' RETURN n.title, n.content"
        elif "document" in user_lower:
            return "MATCH (n:Document) RETURN n.title, n.content LIMIT 5"
        elif "person" in user_lower or "people" in user_lower:
            return "MATCH (n:Person) RETURN n.name, n.role LIMIT 5"
        elif "all" in user_lower:
            return "MATCH (n) RETURN n LIMIT 10"
        else:
            return "MATCH (n:Person) RETURN n.name LIMIT 5"

# Initialize Graph and Vulnerable Chain
graph = None
cypher_chain = None
agent_executor = None

try:
    # Connect to Neo4j
    graph = Neo4jGraph(
        url=NEO4J_URI,
        username=NEO4J_USER,
        password=NEO4J_PASSWORD
    )

    logger.info("Connected to Neo4j")

    # Initialize test data
    graph.query(
        """
        MERGE (p1:Person {name: 'Alice'})
        SET p1.role = 'user'
        MERGE (p2:Person {name: 'Bob'})
        SET p2.role = 'admin'
        MERGE (p3:Person {name: 'Charlie'})
        SET p3.role = 'user'
        MERGE (d1:Document {title: 'Public Doc'})
        SET d1.content = 'This is public information'
        MERGE (d2:Document {title: 'Secret Doc'})
        SET d2.content = $secret_flag
        MERGE (p1)-[:OWNS]->(d1)
        MERGE (p2)-[:OWNS]->(d2)
        """,
        params={"secret_flag": SECRET_FLAG},
    )

    logger.info("Test data initialized with runtime secret flag")

    # VULNERABLE CODE: Create GraphCypherQAChain with NO validation
    # This is the REAL vulnerable component from LangChain 0.2.5
    cypher_chain = GraphCypherQAChain.from_llm(
        llm=MockLLM(),  # In production: ChatOpenAI(model="gpt-3.5-turbo")
        graph=graph,
        verbose=True,
        return_intermediate_steps=True
    )

    logger.info("GraphCypherQAChain initialized (VULNERABLE)")

    # REAL CVE-2024-8309 SCENARIO: Create Agent with GraphCypherQAChain as Tool
    # This is exactly how the vulnerability is triggered in real applications
    tools = [
        Tool(
            name="Graph",
            func=cypher_chain.run,  # VULNERABLE: No validation of generated Cypher!
            description="Useful for querying a knowledge graph database using natural language. Input should be a natural language question about the graph data."
        )
    ]

    # Initialize Agent with the vulnerable tool
    # Using ConversationBufferMemory for realistic agent behavior
    memory = ConversationBufferMemory(memory_key="chat_history", return_messages=True)

    agent_executor = initialize_agent(
        tools=tools,
        llm=MockLLM(),
        agent=AgentType.CONVERSATIONAL_REACT_DESCRIPTION,
        memory=memory,
        verbose=True,
        handle_parsing_errors=True
    )

    logger.info("LangChain Agent initialized with GraphCypherQAChain tool (VULNERABLE)")

except Exception as e:
    logger.error(f"Error initializing: {e}", exc_info=True)

class QueryRequest(BaseModel):
    query: str

@app.get("/")
def read_root():
    return {
        "service": "LangChain Agent with GraphCypherQAChain",
        "version": "0.2.5",
        "vulnerable": "CVE-2024-8309",
        "architecture": "Agent → GraphCypherQAChain Tool → Neo4j",
        "endpoints": {
            "/agent": "POST - Query via LangChain Agent (VULNERABLE)",
            "/direct": "POST - Direct GraphCypherQAChain query (VULNERABLE)",
            "/health": "GET - Health check"
        },
        "vulnerability": "GraphCypherQAChain executes LLM-generated Cypher without validation",
        "attack": "Prompt injection → Malicious Cypher → Database compromise"
    }

@app.get("/health")
def health_check():
    if graph:
        try:
            graph.query("RETURN 1")
            return {
                "status": "healthy",
                "neo4j": "connected",
                "agent": "initialized" if agent_executor else "not_initialized"
            }
        except:
            return {"status": "unhealthy", "neo4j": "disconnected"}
    return {"status": "unhealthy", "neo4j": "not_initialized"}

@app.post("/agent")
def query_agent(request: QueryRequest):
    """
    Query via LangChain Agent with GraphCypherQAChain tool

    CVE-2024-8309 REAL VULNERABILITY:
    1. User controls the agent input
    2. Agent uses GraphCypherQAChain tool
    3. GraphCypherQAChain converts query to Cypher via LLM
    4. LLM is vulnerable to prompt injection
    5. Generated Cypher executed WITHOUT validation
    6. Attacker gains database access

    This is the EXACT scenario from the CVE PoC!
    """
    if not agent_executor:
        raise HTTPException(status_code=503, detail="Agent not initialized")

    try:
        query = request.query
        logger.info(f"[AGENT] Received query: {query}")

        # VULNERABLE: Agent processes user input and uses GraphCypherQAChain
        # User can manipulate the agent via prompt injection
        # Use invoke() to get full response including intermediate steps
        full_result = agent_executor.invoke({"input": query})

        # Extract the output
        result = full_result.get("output", str(full_result))

        # Get intermediate steps if available
        intermediate_steps = full_result.get("intermediate_steps", [])

        logger.info(f"[AGENT] Result: {result}")
        logger.info(f"[AGENT] Intermediate steps: {intermediate_steps}")

        return {
            "message": "Agent query executed",
            "query": query,
            "result": result,
            "intermediate_steps": intermediate_steps,
            "vulnerable": "CVE-2024-8309",
            "note": "Agent used GraphCypherQAChain without Cypher validation"
        }

    except Exception as e:
        logger.error(f"[AGENT] Error: {e}")
        return {
            "error": str(e),
            "query": request.query,
            "note": "Error occurred but malicious query may have executed"
        }

@app.post("/direct")
def query_direct(request: QueryRequest):
    """
    Direct GraphCypherQAChain query (without agent wrapper)

    This endpoint demonstrates the core vulnerability directly
    """
    if not cypher_chain:
        raise HTTPException(status_code=503, detail="GraphCypherQAChain not initialized")

    try:
        query = request.query
        logger.info(f"[DIRECT] Received query: {query}")

        # VULNERABLE: Direct call to GraphCypherQAChain
        # Using invoke() to get the full response including intermediate steps
        full_result = cypher_chain.invoke({"query": query})

        # Extract the final answer
        result = full_result.get("result", str(full_result))

        # Also try to get intermediate steps which contain the actual DB query results
        intermediate_steps = full_result.get("intermediate_steps", [])

        logger.info(f"[DIRECT] Result: {result}")
        logger.info(f"[DIRECT] Intermediate steps: {intermediate_steps}")

        return {
            "message": "Direct query executed",
            "query": query,
            "result": result,
            "intermediate_steps": intermediate_steps,
            "vulnerable": "CVE-2024-8309"
        }

    except Exception as e:
        logger.error(f"[DIRECT] Error: {e}")
        return {
            "error": str(e),
            "query": request.query,
            "note": "Error occurred but malicious query may have executed"
        }

if __name__ == "__main__":
    logger.info("=" * 60)
    logger.info("Starting LangChain Agent with GraphCypherQAChain Server")
    logger.info("Port: 8080")
    logger.info("WARNING: VULNERABLE TO CVE-2024-8309")
    logger.info("GraphCypherQAChain executes Cypher without validation")
    logger.info("=" * 60)
    uvicorn.run(app, host="0.0.0.0", port=8080, log_level="info")
EOFPY

echo "[*] Starting LangChain Agent API server on port 8080..."
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
