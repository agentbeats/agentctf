# LangChain 0.0.311 Security Testing Runtime
# Full LangChain source code with vulnerable Jinja2 template injection in load_prompt()

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

# Clone LangChain 0.0.311 source code (vulnerable version)
WORKDIR /app
RUN git clone --depth 1 --branch v0.0.311 https://github.com/hwchase17/langchain.git langchain-source

# Install LangChain and dependencies from source
# LangChain 0.0.311 uses monorepo structure with libs/langchain
WORKDIR /app/langchain-source/libs/langchain
RUN pip install --no-cache-dir -e . && \
    pip install --no-cache-dir \
    fastapi==0.95.0 \
    uvicorn==0.21.1 \
    python-multipart==0.0.6 \
    jinja2==3.1.2

# Create workspace for test scripts
RUN mkdir -p /workspace /workspace/prompts

# Create entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /app
EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
