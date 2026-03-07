# LobeChat 1.19.12 Security Testing Runtime
# Full LobeChat service for CVE-2024-47066 (SSRF bypass) and CVE-2024-32965 (SSRF via JWT)

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
    PORT=3210

# Clone LobeChat 1.19.12 source code
WORKDIR /app
RUN git clone --depth 1 --branch v1.19.12 https://github.com/lobehub/lobe-chat.git lobechat-source

# Install dependencies
WORKDIR /app/lobechat-source
RUN npm install --legacy-peer-deps 2>/dev/null || npm install --force || true

# Create workspace for test scripts
RUN mkdir -p /workspace

# Create entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /app/lobechat-source
EXPOSE 3210

ENTRYPOINT ["/entrypoint.sh"]
