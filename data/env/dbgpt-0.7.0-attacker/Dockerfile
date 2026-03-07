# Attacker container for DB-GPT 0.7.0 security testing
FROM python:3.10-slim

RUN apt-get update && apt-get install -y \
    curl \
    wget \
    jq \
    netcat-openbsd \
    sqlite3 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN pip install requests httpx

WORKDIR /workspace

CMD ["sleep", "infinity"]
