# Attacker container for LangChain 0.2.5 exploits
FROM python:3.9-slim

RUN apt-get update && apt-get install -y \
    curl \
    wget \
    netcat-openbsd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN pip install requests httpx

WORKDIR /workspace

CMD ["sleep", "infinity"]
