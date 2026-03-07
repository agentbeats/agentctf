# gpt_academic 3.36 Security Testing Runtime
# Self-contained Docker image with gpt_academic source code included
# Version 3.36 - Vulnerable to CVE-2023-33979 (Config File Disclosure)

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

# Clone gpt_academic 3.36 source code
WORKDIR /app
RUN git clone https://github.com/binary-husky/gpt_academic.git gpt_academic-source && \
    cd gpt_academic-source && \
    git checkout version3.36

# Install dependencies
WORKDIR /app/gpt_academic-source
RUN pip install --upgrade pip && \
    (pip install --no-cache-dir -r requirements.txt --use-deprecated=legacy-resolver 2>/dev/null || \
     pip install --no-cache-dir numpy loguru requests beautifulsoup4 gradio colorama flask)

# Create workspace
RUN mkdir -p /workspace

# Set working directory
WORKDIR /app/gpt_academic-source

# Entry point for testing
CMD ["python"]
