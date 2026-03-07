# LangChain 0.2.5 Security Testing Runtime
# Full LangChain source code with vulnerable GraphCypherQAChain allowing Cypher injection

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

# Clone LangChain 0.2.5 source code (vulnerable version)
WORKDIR /app
RUN git clone --depth 1 --branch langchain==0.2.5 https://github.com/langchain-ai/langchain.git langchain-source

# Install LangChain and dependencies from source
# LangChain 0.2.5 uses monorepo structure with libs/langchain
WORKDIR /app/langchain-source/libs/langchain
RUN pip install --no-cache-dir -e . && \
    pip install --no-cache-dir \
    langchain-community==0.2.5 \
    langchain-openai==0.1.8 \
    neo4j==5.11.0 \
    fastapi==0.111.0 \
    uvicorn==0.30.1 \
    python-multipart==0.0.9

# Create workspace for test scripts
RUN mkdir -p /workspace /workspace/cypher_queries

# Create entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /app
EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
