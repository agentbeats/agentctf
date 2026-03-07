# Attacker container for lobechat 1.19.12 security testing

FROM python:3.11-slim

RUN apt-get update && apt-get install -y \
    curl \
    wget \
    netcat-traditional \
    jq \
    git \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir \
    requests \
    beautifulsoup4 \
    lxml

RUN mkdir -p /workspace

WORKDIR /workspace

CMD ["sleep", "infinity"]
