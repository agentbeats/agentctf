# AgentScope 0.0.4 Security Testing Runtime
# Self-contained Docker image with agentscope source code included

FROM python:3.10-slim AS base

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set environment variables
ENV PIP_NO_CACHE_DIR=yes \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="$PATH:/root/.local/bin"

# Clone agentscope 0.0.4 source code into container
WORKDIR /app
RUN git clone https://github.com/modelscope/agentscope.git agentscope-source && \
    cd agentscope-source && \
    git checkout v0.0.4

# Install dependencies including distribute extras for RPC support
WORKDIR /app/agentscope-source
RUN pip install --upgrade pip && \
    pip install --no-cache-dir -e .[distribute] || \
    (pip install --no-cache-dir agentscope==0.0.4 && \
     pip install --no-cache-dir grpcio grpcio-tools protobuf expiringdict dill psutil)

# Install Flask for HTTP wrapper
RUN pip install --no-cache-dir flask

# Copy HTTP server wrapper for CVE-2024-48050
COPY agentscope_rce_server.py /app/agentscope_rce_server.py
RUN chmod +x /app/agentscope_rce_server.py

# Create workspace directory
RUN mkdir -p /workspace

# Create entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set working directory
WORKDIR /app/agentscope-source

EXPOSE 5000

ENTRYPOINT ["/entrypoint.sh"]
