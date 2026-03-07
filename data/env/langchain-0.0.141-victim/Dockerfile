# LangChain 0.0.141 Security Testing Runtime
# Full LangChain source code with vulnerable LLMMathChain

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

# Clone LangChain 0.0.141 source code (corresponds to tag v0.0.141)
WORKDIR /app
RUN git clone --depth 1 --branch v0.0.141 https://github.com/hwchase17/langchain.git langchain-source

# Install LangChain and dependencies from source
WORKDIR /app/langchain-source
RUN pip install --no-cache-dir -e . && \
    pip install --no-cache-dir \
    fastapi==0.95.0 \
    uvicorn==0.21.1 \
    openai==0.27.6

# Create workspace for test scripts
RUN mkdir -p /workspace

# Create entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /app/langchain-source
EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
