# LangChain 0.1.11 Security Testing Runtime
# CVE-2024-28088: Directory traversal in load_chain allowing RCE

FROM python:3.9-slim AS base

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    procps \
    netcat-openbsd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PORT=8080

# Clone LangChain 0.1.11 source code (corresponds to tag v0.1.11)
WORKDIR /app
RUN git clone --depth 1 --branch v0.1.11 https://github.com/langchain-ai/langchain.git langchain-source

# Install specific compatible versions to avoid dependency hell
# CRITICAL: Must use langchain-core==0.1.29 - the last version with vulnerable hub loading
# langchain-core>=0.1.30 disabled hub loading entirely
# openai<1.0.0 to avoid proxies parameter issue
WORKDIR /app/langchain-source/libs/langchain
RUN pip install --no-cache-dir \
    "langchain==0.1.11" \
    "langchain-core==0.1.29" \
    "langchain-community==0.0.25" \
    "langchain-experimental" \
    "fastapi==0.109.0" \
    "uvicorn==0.27.0" \
    "openai==0.28.1"

# Create workspace for test scripts
RUN mkdir -p /workspace

# Create entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /app/langchain-source
EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
