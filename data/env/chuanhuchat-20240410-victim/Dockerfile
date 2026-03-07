# ChuanhuChatGPT v20240410 Runtime Environment
# Multiple CVEs: CVE-2024-6255, CVE-2024-6037, CVE-2024-6035

FROM python:3.10-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    build-essential \
    wget \
    netcat-openbsd \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Clone ChuanhuChatGPT v20240410 (vulnerable version)
RUN git clone --depth 1 --branch 20240410 https://github.com/gaizhenbiao/ChuanhuChatGPT.git chuanhuchat-source

WORKDIR /app/chuanhuchat-source

# Upgrade pip and install build tools
RUN pip install --no-cache-dir --upgrade pip setuptools wheel

# Install minimal dependencies for the vulnerable functionality
RUN pip install --no-cache-dir \
    huggingface_hub==0.21.4 \
    gradio==4.26.0 \
    gradio_client==0.15.1 \
    pypinyin \
    tiktoken \
    colorama \
    commentjson \
    pydantic==2.5.2 \
    requests \
    httpx

# Create necessary directories
RUN mkdir -p /app/history /workspace /tmp

# Create entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /workspace

# Expose Gradio default port
EXPOSE 7860

# Set Python to unbuffered mode
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

ENTRYPOINT ["/entrypoint.sh"]
