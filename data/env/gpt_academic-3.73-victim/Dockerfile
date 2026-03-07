# gpt_academic 3.73 Security Testing Runtime
# Self-contained Docker image with gpt_academic source code included

FROM python:3.11-slim AS base

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

# Clone gpt_academic 3.73 source code (commit before the fix)
WORKDIR /app
RUN git clone https://github.com/binary-husky/gpt_academic.git gpt_academic-source && \
    cd gpt_academic-source && \
    git checkout 8af6c0cab6d96f5c4520bec85b24802e6e823f35~1

# Install dependencies
WORKDIR /app/gpt_academic-source
RUN pip install --upgrade pip && \
    pip install --no-cache-dir flask requests

# Create workspace
RUN mkdir -p /workspace

# Set working directory
WORKDIR /app/gpt_academic-source

# Entry point for testing
CMD ["python"]
