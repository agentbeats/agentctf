# Attacker container for LobeChat 1.130.0 security testing
FROM python:3.11-slim

RUN apt-get update && apt-get install -y \
    curl \
    wget \
    jq \
    netcat-openbsd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN pip install requests pyjwt httpx

WORKDIR /workspace

CMD ["sleep", "infinity"]
