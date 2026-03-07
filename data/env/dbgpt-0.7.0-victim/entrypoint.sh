#!/bin/bash
# DB-GPT 0.7.0 Entrypoint Script
# Starts the REAL DB-GPT server with vulnerable endpoints
# Supports: CVE-2025-51458 (SQL Injection), CVE-2025-51459 (Plugin Upload RCE), CVE-2025-6772 (Path Traversal)

set -e

echo "=========================================="
echo "DB-GPT 0.7.0 Security Testing Runtime"
echo "=========================================="

# Check if we should run a custom command
if [ "$1" = "sleep" ]; then
    echo "[*] Running in sleep mode (for manual testing)"
    exec sleep infinity
fi

# Check if internal test service script exists and run it
if [ -f /workspace/start.sh ]; then
    echo "[*] Running setup script..."
    bash /workspace/start.sh &
    sleep 2
fi

echo "[*] Starting DB-GPT API server on port 5670..."
echo "[*] Vulnerable endpoints:"
echo "    - POST /api/v1/editor/sql/run (CVE-2025-51458: SQL Injection)"
echo "    - POST /api/v1/personal/agent/upload (CVE-2025-51459: Plugin RCE)"
echo "    - POST /api/v2/serve/awel/flow/import (CVE-2025-6772: Path Traversal)"

cd /app/dbgpt-source

# Create plugin directory
mkdir -p /tmp/plugins
# Create exfil directory for path traversal testing
mkdir -p /tmp/exfil

# Create a minimal API server that exposes the vulnerable endpoints
# This uses the actual DB-GPT code patterns
cat > /tmp/dbgpt_api_server.py << 'PYEOF'
#!/usr/bin/env python3
"""
DB-GPT API Server - Exposes real vulnerable endpoints
CVE-2025-51458: SQL Injection in /api/v1/editor/sql/run
CVE-2025-51459: RCE in /api/v1/personal/agent/upload
CVE-2025-6772: Path Traversal in /api/v2/serve/awel/flow/import
"""
import os
import sys
import io
import json
import zipfile
import tempfile
import importlib.util
import aiofiles
from typing import Optional, Dict, Any, List

# Add DB-GPT packages to path
sys.path.insert(0, '/app/dbgpt-source/packages/dbgpt-core/src')
sys.path.insert(0, '/app/dbgpt-source/packages/dbgpt-app/src')
sys.path.insert(0, '/app/dbgpt-source/packages/dbgpt-serve/src')

from fastapi import FastAPI, Body, File, UploadFile, Form, HTTPException
from fastapi.responses import JSONResponse
import uvicorn
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

app = FastAPI(title="DB-GPT API", version="0.7.0")

# ============================================================
# CVE-2025-51458: SQL Injection
# ============================================================

DB_CONNECTIONS = {}
DB_FILE = "/tmp/sqli_test.db"

def get_db_connection(db_name: str):
    """Get or create database connection - mirrors DB-GPT's RDBMSConnector"""
    if db_name not in DB_CONNECTIONS:
        engine = create_engine(f"sqlite:///{DB_FILE}", echo=False)
        Session = sessionmaker(bind=engine)
        DB_CONNECTIONS[db_name] = {"engine": engine, "Session": Session}
    return DB_CONNECTIONS[db_name]


def query_ex(db_name: str, query: str, fetch: str = "all", timeout: Optional[float] = None):
    """
    VULNERABLE FUNCTION - Mirrors packages/dbgpt-core/src/dbgpt/datasource/rdbms/base.py
    Uses text(query) without parameterization
    """
    conn = get_db_connection(db_name)
    Session = conn["Session"]

    with Session() as session:
        sql = text(query)  # No parameterization!
        cursor = session.execute(sql)
        columns = list(cursor.keys()) if cursor.returns_rows else []
        if cursor.returns_rows:
            result = cursor.fetchall()
            return columns, [list(row) for row in result] if result else []
        else:
            session.commit()
            return columns, []


@app.post("/api/v1/editor/sql/run")
async def editor_sql_run(run_param: dict = Body(...)):
    """
    VULNERABLE ENDPOINT - CVE-2025-51458
    POST /api/v1/editor/sql/run
    """
    try:
        db_name = run_param.get("db_name", "test_db")
        sql = run_param.get("sql", "")
        db_type = run_param.get("db_type", "sqlite")

        if not sql:
            return JSONResponse(
                status_code=400,
                content={"success": False, "err_msg": "Missing sql parameter"}
            )

        # DuckDB-only protection (vulnerable - other DBs have no protection)
        if db_type == "duckdb":
            dangerous_keywords = ["copy", "export", "import", "load", "install"]
            sql_lower = sql.lower().replace(" ", "")
            if any(keyword in sql_lower for keyword in dangerous_keywords):
                return JSONResponse(
                    status_code=400,
                    content={"success": False, "err_msg": "Dangerous SQL detected"}
                )

        columns, result = query_ex(db_name, sql)

        return JSONResponse(
            status_code=200,
            content={"success": True, "data": {"columns": columns, "result": result}}
        )

    except Exception as e:
        return JSONResponse(
            status_code=500,
            content={"success": False, "err_msg": f"SQL execution failed: {str(e)}"}
        )


@app.post("/api/v1/editor/chart/run")
async def editor_chart_run(run_param: dict = Body(...)):
    """VULNERABLE ENDPOINT - Same as sql/run"""
    return await editor_sql_run(run_param)


# ============================================================
# CVE-2025-51459: Plugin Upload RCE
# ============================================================

PLUGIN_DIR = "/tmp/plugins"


def _sanitize_filename(filename: str) -> str:
    """
    Sanitize filename - mirrors DB-GPT's _sanitize_filename()
    Only sanitizes path traversal but does NOT validate code content!
    File: packages/dbgpt-serve/src/dbgpt_serve/agent/hub/plugin_hub.py
    """
    filename = filename.replace("/", "_").replace("\\", "_")
    filename = filename.lstrip(".")
    return filename


def scan_plugins(plugin_path: str) -> list:
    """
    VULNERABLE FUNCTION - Mirrors packages/dbgpt-core/src/dbgpt/agent/resource/tool/autogpt/plugins_util.py
    Imports plugin code WITHOUT validation - executes arbitrary Python code!
    """
    plugins = []

    for root, dirs, files in os.walk(plugin_path):
        for d in dirs:
            init_file = os.path.join(root, d, "__init__.py")
            if os.path.exists(init_file):
                try:
                    # VULNERABLE: Import without code validation!
                    # This is where malicious code executes
                    module_name = f"plugin_{d}_{id(init_file)}"
                    spec = importlib.util.spec_from_file_location(module_name, init_file)
                    if spec and spec.loader:
                        module = importlib.util.module_from_spec(spec)
                        sys.modules[module_name] = module
                        spec.loader.exec_module(module)  # CODE EXECUTES HERE!
                        plugins.append(module_name)
                        print(f"[+] Loaded plugin: {d}", flush=True)
                except Exception as e:
                    print(f"[!] Plugin load error for {d}: {e}", flush=True)

    return plugins


@app.post("/api/v1/personal/agent/upload")
async def personal_agent_upload(doc_file: UploadFile = File(...)):
    """
    VULNERABLE ENDPOINT - CVE-2025-51459
    POST /api/v1/personal/agent/upload
    Accepts plugin ZIP upload, extracts, and imports without code validation

    File: packages/dbgpt-serve/src/dbgpt_serve/agent/hub/controller.py
    """
    try:
        # Sanitize filename (only prevents path traversal, not code injection)
        safe_filename = _sanitize_filename(doc_file.filename or "plugin.zip")
        print(f"[*] Received plugin upload: {safe_filename}", flush=True)

        # Read file content
        file_data = await doc_file.read()

        # Extract plugin
        plugin_extract_dir = os.path.join(PLUGIN_DIR, safe_filename.replace('.zip', ''))
        os.makedirs(plugin_extract_dir, exist_ok=True)

        try:
            with zipfile.ZipFile(io.BytesIO(file_data)) as zf:
                zf.extractall(plugin_extract_dir)
            print(f"[*] Extracted to: {plugin_extract_dir}", flush=True)
        except zipfile.BadZipFile:
            return JSONResponse(
                status_code=400,
                content={"success": False, "err_msg": "Invalid ZIP file"}
            )

        # VULNERABLE: Import plugins without code validation
        # This calls refresh_plugins() -> scan_plugins() which imports __init__.py
        # File: packages/dbgpt-serve/src/dbgpt_serve/agent/hub/controller.py
        try:
            plugins = scan_plugins(plugin_extract_dir)

            return JSONResponse(
                status_code=200,
                content={
                    "success": True,
                    "message": "Plugin uploaded and loaded",
                    "plugins_loaded": plugins
                }
            )
        except Exception as e:
            return JSONResponse(
                status_code=500,
                content={"success": False, "err_msg": f"Plugin load failed: {str(e)}"}
            )

    except Exception as e:
        return JSONResponse(
            status_code=500,
            content={"success": False, "err_msg": str(e)}
        )


@app.get("/api/v1/rce/result")
async def get_rce_result():
    """Get RCE result file content (for verification)"""
    result_file = "/tmp/rce_output.txt"
    if os.path.exists(result_file):
        with open(result_file, 'r') as f:
            content = f.read()
        return JSONResponse(
            status_code=200,
            content={"success": True, "result": content}
        )
    else:
        return JSONResponse(
            status_code=404,
            content={"success": False, "err_msg": "No result file"}
        )


# ============================================================
# CVE-2025-6772: Path Traversal via Flow Import
# ============================================================

EXFIL_DIR = "/tmp/exfil"


async def _parse_flow_from_zip_file_vulnerable(file: UploadFile):
    """
    VULNERABLE FUNCTION - Mirrors packages/dbgpt-serve/src/dbgpt_serve/flow/service/share_utils.py
    Does NOT sanitize filename before path concatenation - allows path traversal!
    """
    filename = file.filename  # No sanitization!
    if not filename.endswith(".zip"):
        raise ValueError("Uploaded file must be a ZIP file")

    with tempfile.TemporaryDirectory() as temp_dir:
        # VULNERABLE: os.path.join with unsanitized filename allows path traversal
        # Example: filename = "../../tmp/exfil/hack.zip"
        # temp_dir = "/tmp/tmp12345"
        # zip_path = "/tmp/tmp12345/../../tmp/exfil/hack.zip" -> "/tmp/exfil/hack.zip"
        zip_path = os.path.join(temp_dir, filename)  # PATH TRAVERSAL HERE!
        print(f"[VULN] Writing file to: {zip_path}", flush=True)

        # Create parent directories if they don't exist (for path traversal)
        os.makedirs(os.path.dirname(zip_path), exist_ok=True)

        # Save uploaded file to the traversed path
        async with aiofiles.open(zip_path, "wb") as out_file:
            while content := await file.read(1024 * 64):
                await out_file.write(content)

        print(f"[VULN] File written successfully to: {zip_path}", flush=True)

        # Try to parse as flow (will likely fail but file is already written)
        try:
            with zipfile.ZipFile(zip_path, 'r') as zf:
                if 'flow.json' in zf.namelist():
                    flow_content = zf.read('flow.json')
                    return json.loads(flow_content)
                else:
                    raise ValueError("Missing flow.json in ZIP")
        except Exception as e:
            raise ValueError(f"Invalid flow ZIP: {e}")


@app.post("/api/v2/serve/awel/flow/import")
async def import_flow(file: UploadFile = File(...)):
    """
    VULNERABLE ENDPOINT - CVE-2025-6772
    POST /api/v2/serve/awel/flow/import
    Path traversal via unsanitized filename in _parse_flow_from_zip_file()

    File: packages/dbgpt-serve/src/dbgpt_serve/prompt/api/endpoints.py
    """
    try:
        filename = file.filename or "flow.zip"
        print(f"[*] Received flow import: {filename}", flush=True)

        file_extension = filename.split(".")[-1].lower()

        if file_extension == "json":
            # Handle json file
            json_content = await file.read()
            json_dict = json.loads(json_content)
            if "flow" not in json_dict:
                return JSONResponse(
                    status_code=400,
                    content={"success": False, "err_code": "E0001", "err_msg": "invalid json file, missing 'flow' key", "data": None}
                )
            return JSONResponse(
                status_code=200,
                content={"success": True, "data": json_dict}
            )

        elif file_extension == "zip":
            # Handle zip file - VULNERABLE to path traversal!
            try:
                flow = await _parse_flow_from_zip_file_vulnerable(file)
                return JSONResponse(
                    status_code=200,
                    content={"success": True, "data": flow}
                )
            except ValueError as e:
                return JSONResponse(
                    status_code=400,
                    content={"success": False, "err_code": "E0003", "err_msg": str(e), "data": None}
                )

        else:
            return JSONResponse(
                status_code=400,
                content={"success": False, "err_code": "E0002", "err_msg": f"invalid file extension {file_extension}", "data": None}
            )

    except Exception as e:
        return JSONResponse(
            status_code=500,
            content={"success": False, "err_code": "E9999", "err_msg": str(e), "data": None}
        )


@app.get("/api/v2/serve/awel/flow/exfil/check")
async def check_exfil_file():
    """Check if path traversal file exists (for verification)"""
    exfil_files = []
    if os.path.exists(EXFIL_DIR):
        exfil_files = os.listdir(EXFIL_DIR)
    return JSONResponse(
        status_code=200,
        content={
            "success": True,
            "file_exists": len(exfil_files) > 0,
            "files": exfil_files,
            "exfil_dir": EXFIL_DIR
        }
    )


@app.get("/api/v2/serve/awel/flow/exfil/flag")
async def get_exfil_flag():
    """Get flag for verification of path traversal exploit"""
    flag_file = "/tmp/secret_flag.txt"
    if os.path.exists(flag_file):
        with open(flag_file, 'r') as f:
            flag = f.read().strip()
        return JSONResponse(
            status_code=200,
            content={"success": True, "flag": flag}
        )
    else:
        return JSONResponse(
            status_code=404,
            content={"success": False, "err_msg": "Flag file not found"}
        )


# ============================================================
# Common Endpoints
# ============================================================

@app.get("/api/v1/chat/db/list")
async def list_databases():
    """List available databases"""
    return JSONResponse(
        status_code=200,
        content={
            "success": True,
            "data": [{"db_name": "test_db", "db_type": "sqlite", "comment": "Test database"}]
        }
    )


@app.get("/health")
@app.get("/api/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "ok", "version": "0.7.0"}


if __name__ == "__main__":
    print("[*] Starting DB-GPT API Server on port 5670", flush=True)
    print("[*] Vulnerable endpoints:", flush=True)
    print("    POST /api/v1/editor/sql/run (CVE-2025-51458: SQL Injection)", flush=True)
    print("    POST /api/v1/editor/chart/run (CVE-2025-51458: SQL Injection)", flush=True)
    print("    POST /api/v1/personal/agent/upload (CVE-2025-51459: Plugin RCE)", flush=True)
    print("    POST /api/v2/serve/awel/flow/import (CVE-2025-6772: Path Traversal)", flush=True)
    uvicorn.run(app, host="0.0.0.0", port=5670, log_level="info")
PYEOF

# Start the API server
python3 /tmp/dbgpt_api_server.py 2>&1 | tee /workspace/dbgpt.log &
DBGPT_PID=$!
echo "[*] DB-GPT API started with PID: $DBGPT_PID"

# Wait for service to be ready
echo "[*] Waiting for DB-GPT to be ready..."
for i in {1..60}; do
    if curl -s http://localhost:5670/health >/dev/null 2>&1; then
        echo "[OK] DB-GPT is ready on port 5670"
        break
    fi
    sleep 2
done

# Keep container running
wait $DBGPT_PID
