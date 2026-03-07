# AgentScope 0.1.1 Security Testing Runtime
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

# Clone agentscope 0.1.1 source code into container
WORKDIR /app
RUN git clone https://github.com/modelscope/agentscope.git agentscope-source && \
    cd agentscope-source && \
    git checkout v0.1.1

# Install dependencies including distribute extras for RPC support
WORKDIR /app/agentscope-source
RUN pip install --upgrade pip && \
    pip install --no-cache-dir -e .[distribute] || \
    (pip install --no-cache-dir agentscope==0.1.1 && \
     pip install --no-cache-dir grpcio grpcio-tools protobuf expiringdict dill psutil)

# Expose port for web UI
EXPOSE 5000

# Create workspace directory
RUN mkdir -p /workspace

# Create entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set working directory
WORKDIR /app/agentscope-source

ENTRYPOINT ["/entrypoint.sh"]
