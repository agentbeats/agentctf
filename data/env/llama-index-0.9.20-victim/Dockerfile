# Llama Index 0.9.20 Security Testing Runtime
# CVE-2024-3098: Vulnerable regex-based safe_eval allowing getattr() bypass

FROM python:3.10-slim AS base

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
    PORT=8080 \
    OPENAI_API_KEY=sk-1234567890abcdef1234567890abcdef1234567890abcdef

# Install llama-index 0.9.20 (vulnerable version with regex-based safe_eval)
# This version uses regex pattern r"_{1,2}\w+_{0,2}" which can be bypassed
WORKDIR /app
RUN pip install --no-cache-dir numpy==1.24.3 \
    llama-index==0.9.20 \
    pandas==2.0.3 \
    fastapi==0.109.0 \
    uvicorn==0.27.0 \
    pydantic==2.5.0

# Clone source code for reference
RUN git clone --depth 1 --branch v0.9.20 https://github.com/run-llama/llama_index.git llama-index-source || \
    git clone --depth 1 https://github.com/run-llama/llama_index.git llama-index-source

# Create workspace for test scripts
RUN mkdir -p /workspace

WORKDIR /workspace

# Create entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
