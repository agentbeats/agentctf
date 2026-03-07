# Attacker container for AgentScope 0.0.4 security testing
FROM python:3.9-slim

RUN apt-get update && apt-get install -y \
    curl \
    wget \
    netcat-traditional \
    jq \
    git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir \
    requests \
    beautifulsoup4 \
    lxml

RUN mkdir -p /workspace

WORKDIR /workspace

CMD ["sleep", "infinity"]
