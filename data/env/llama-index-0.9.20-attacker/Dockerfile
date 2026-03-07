# Attacker container for Llama Index 0.10.23 security testing
FROM python:3.10-slim

RUN apt-get update && apt-get install -y \
    curl \
    wget \
    jq \
    netcat-openbsd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN pip install requests httpx

WORKDIR /workspace

CMD ["sleep", "infinity"]
