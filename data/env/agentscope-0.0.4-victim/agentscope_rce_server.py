#!/usr/bin/env python3
"""
Simple HTTP server wrapper to expose AgentScope workflow_utils RCE vulnerability
This is for security testing of CVE-2024-48050
"""
import sys
import os
from flask import Flask, request, jsonify

# Add AgentScope to path
sys.path.insert(0, '/app/agentscope-source/src')

# Import the vulnerable function
from agentscope.web.workstation.workflow_utils import is_callable_expression, kwarg_converter

app = Flask(__name__)

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({"status": "ok", "service": "AgentScope RCE Test Server"})

@app.route('/api/test_callable', methods=['POST'])
def test_callable():
    """
    Test if expression is callable (VULNERABLE to RCE via eval)
    """
    try:
        data = request.get_json()
        expression = data.get('expression', '')

        if not expression:
            return jsonify({"error": "expression is required"}), 400

        # Call the vulnerable function
        result = is_callable_expression(expression)

        return jsonify({
            "success": True,
            "is_callable": result,
            "expression": expression
        })

    except Exception as e:
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/workstation/api/create_workflow', methods=['POST'])
def create_workflow():
    """
    Simulate workflow creation endpoint (triggers kwarg_converter)
    """
    try:
        data = request.get_json()
        workflow_data = data.get('data', {})

        results = {}
        for node_id, node_info in workflow_data.items():
            args = node_info.get('data', {}).get('args', {})

            # Process args through kwarg_converter (vulnerable)
            for key, value in args.items():
                if isinstance(value, str):
                    if is_callable_expression(value):
                        results[key] = eval(value)
                    else:
                        try:
                            results[key] = eval(value)
                        except:
                            results[key] = value
                else:
                    results[key] = value

        return jsonify({
            "success": True,
            "processed_args": results
        })

    except Exception as e:
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

if __name__ == '__main__':
    print("=" * 50)
    print("AgentScope RCE Test Server Starting")
    print("=" * 50)
    print("")
    print("Endpoints:")
    print("  GET  /health                           - Health check")
    print("  POST /api/test_callable                - Test callable (RCE)")
    print("  POST /workstation/api/create_workflow  - Create workflow (RCE)")
    print("")
    print("Server: http://0.0.0.0:5000")
    print("=" * 50)
    print("")

    app.run(host='0.0.0.0', port=5000, debug=False)
