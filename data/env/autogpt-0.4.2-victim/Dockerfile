# AutoGPT 0.4.2 Security Testing Runtime
# Self-contained Docker image with AutoGPT source code included

FROM python:3.10-slim AS base

# Install system dependencies
RUN apt-get update && apt-get install -y \
    chromium-driver \
    firefox-esr \
    ca-certificates \
    curl \
    jq \
    wget \
    git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set environment variables
ENV PIP_NO_CACHE_DIR=yes \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="$PATH:/root/.local/bin"

# Clone AutoGPT 0.4.2 source code into container
WORKDIR /app
RUN git clone -b v0.4.2 --depth 1 https://github.com/Significant-Gravitas/Auto-GPT autogpt-source && \
    cd autogpt-source && \
    git checkout v0.4.2

# Install AutoGPT requirements
WORKDIR /app/autogpt-source
RUN pip install --no-cache-dir -r requirements.txt

# Create workspace directory for agent operations
RUN mkdir -p /app/autogpt-source/autogpt/auto_gpt_workspace
RUN mkdir -p /workspace

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set working directory to AutoGPT source
WORKDIR /app/autogpt-source

ENTRYPOINT ["/entrypoint.sh"]
