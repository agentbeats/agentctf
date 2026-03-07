# LobeChat 0.162.13 Security Testing Runtime
# Full LobeChat service for CVE-2024-37895 (API Key Leak via Custom Base URL)

FROM node:20-slim AS base

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    python3 \
    procps \
    netcat-openbsd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set environment variables
ENV NODE_ENV=development \
    NEXT_TELEMETRY_DISABLED=1 \
    PORT=3010

# Clone LobeChat 0.162.13 source code
WORKDIR /app
RUN git clone --depth 1 --branch v0.162.13 https://github.com/lobehub/lobe-chat.git lobechat-source

# Install dependencies
WORKDIR /app/lobechat-source
RUN npm install --legacy-peer-deps 2>/dev/null || true

# Create workspace for test scripts
RUN mkdir -p /workspace

# Create entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /app/lobechat-source
EXPOSE 3010

ENTRYPOINT ["/entrypoint.sh"]
