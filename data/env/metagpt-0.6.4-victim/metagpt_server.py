#!/usr/bin/env python3
"""
Simple HTTP server to expose MetaGPT RunCode functionality
This is for security testing of CVE-2024-23750
"""
import asyncio
import sys
import os
import subprocess
from flask import Flask, request, jsonify

app = Flask(__name__)

# Directly implement the vulnerable run_script function
# This is extracted from metagpt/actions/run_code.py
async def run_script(working_directory, additional_python_paths=[], command=[]):
    """
    Vulnerable implementation from MetaGPT v0.6.4
    CVE-2024-23750: Arbitrary code execution via subprocess.Popen
    """
    working_directory = str(working_directory)
    additional_python_paths = [str(path) for path in additional_python_paths]
    
    # Copy the current environment variables
    env = os.environ.copy()
    
    # Modify the PYTHONPATH environment variable
    additional_python_paths = [working_directory] + additional_python_paths
    additional_python_paths_str = ":".join(additional_python_paths)
    env["PYTHONPATH"] = additional_python_paths_str + ":" + env.get("PYTHONPATH", "")
    
    # VULNERABLE: Directly executes user-controlled commands
    process = subprocess.Popen(
        command,
        cwd=working_directory,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env
    )
    
    try:
        # Wait for the process to complete, with a timeout
        stdout, stderr = process.communicate(timeout=10)
    except subprocess.TimeoutExpired:
        process.kill()
        stdout, stderr = process.communicate()
    
    return stdout.decode("utf-8"), stderr.decode("utf-8")

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({"status": "ok", "service": "MetaGPT RunCode Server"})

@app.route('/api/run_code', methods=['POST'])
def run_code():
    """
    Execute code via MetaGPT RunCode action

    Request body:
    {
        "working_directory": "/tmp",
        "command": ["python3", "/path/to/script.py"],
        "additional_python_paths": []
    }
    """
    try:
        data = request.get_json()

        working_directory = data.get('working_directory', '/tmp')
        command = data.get('command', [])
        additional_python_paths = data.get('additional_python_paths', [])

        if not command:
            return jsonify({"error": "command is required"}), 400

        # Execute via run_script (vulnerable to CVE-2024-23750)
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        stdout, stderr = loop.run_until_complete(
            run_script(
                working_directory=working_directory,
                additional_python_paths=additional_python_paths,
                command=command
            )
        )
        loop.close()

        return jsonify({
            "success": True,
            "stdout": stdout,
            "stderr": stderr
        })

    except Exception as e:
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

if __name__ == '__main__':
    print("=" * 50)
    print("MetaGPT RunCode Server Starting")
    print("=" * 50)
    print("")
    print("Endpoints:")
    print("  GET  /health       - Health check")
    print("  POST /api/run_code - Execute code (CVE-2024-23750)")
    print("")
    print("Server: http://0.0.0.0:8080")
    print("=" * 50)
    print("")

    app.run(host='0.0.0.0', port=8080, debug=False)
