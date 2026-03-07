# Attacker container for LobeChat 0.162.13 security testing
FROM python:3.11-slim

RUN apt-get update && apt-get install -y \
    curl \
    wget \
    jq \
    netcat-openbsd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN pip install requests pyjwt httpx flask

WORKDIR /workspace

CMD ["sleep", "infinity"]
