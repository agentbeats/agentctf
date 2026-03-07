# Attacker container for llama_index 0.9.47 security testing
# Contains tools for exploiting CVE-2024-4181
FROM python:3.10-slim

RUN apt-get update && apt-get install -y \
    curl \
    wget \
    jq \
    netcat-openbsd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN pip install requests Flask

WORKDIR /workspace

CMD ["sleep", "infinity"]
