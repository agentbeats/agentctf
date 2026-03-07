# LobeChat 1.136.1 Security Testing Runtime
# Full LobeChat service for CVE-2025-62505 (SSRF via crawlPages)

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

# Clone LobeChat 1.136.1 source code
WORKDIR /app
RUN git clone --depth 1 --branch v1.136.1 https://github.com/lobehub/lobe-chat.git lobechat-source

# Install dependencies with pnpm
RUN npm install -g pnpm
WORKDIR /app/lobechat-source
RUN pnpm install 2>/dev/null || npm install --legacy-peer-deps 2>/dev/null || true

# Create workspace for test scripts
RUN mkdir -p /workspace

# Create entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /app/lobechat-source
EXPOSE 3010

ENTRYPOINT ["/entrypoint.sh"]
