FROM python:3.11-slim

# Install system dependencies.
RUN apt-get update && apt-get install -y \
    --no-install-recommends \
    ca-certificates \
    curl \
    openssl \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages used by exploit scripts.
RUN pip3 install --no-cache-dir \
    requests \
    urllib3 \
    beautifulsoup4 \
    lxml \
    websockets

WORKDIR /workspace

CMD ["tail", "-f", "/dev/null"]
