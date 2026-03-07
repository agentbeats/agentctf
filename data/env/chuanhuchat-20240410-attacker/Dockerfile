# Attacker container for ChuanhuChatGPT 20240410 security testing
FROM python:3.10-slim

RUN apt-get update && apt-get install -y \
    curl \
    wget \
    jq \
    netcat-openbsd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir requests httpx gradio_client

WORKDIR /workspace

CMD ["sleep", "infinity"]
