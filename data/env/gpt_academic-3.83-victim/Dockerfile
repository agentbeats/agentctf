# gpt_academic 3.83 Security Testing Runtime
# Self-contained Docker image with gpt_academic source code included

FROM python:3.11-slim AS base

# Install system dependencies (including manim dependencies)
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    ffmpeg \
    libcairo2-dev \
    libpango1.0-dev \
    texlive \
    texlive-latex-extra \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set environment variables
ENV PIP_NO_CACHE_DIR=yes \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="$PATH:/root/.local/bin"

# Clone gpt_academic 3.83 source code
WORKDIR /app
RUN git clone https://github.com/binary-husky/gpt_academic.git gpt_academic-source && \
    cd gpt_academic-source && \
    git checkout version3.83

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
