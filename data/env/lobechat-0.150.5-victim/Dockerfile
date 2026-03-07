# LobeChat 0.150.5 Security Testing Runtime
# Full LobeChat service with development mode for vulnerability testing

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

# Clone LobeChat 0.150.5 source code
WORKDIR /app
RUN git clone --depth 1 --branch v0.150.5 https://github.com/lobehub/lobe-chat.git lobechat-source

# Install dependencies
WORKDIR /app/lobechat-source
RUN npm install --legacy-peer-deps 2>/dev/null || true

# Create workspace for test scripts
RUN mkdir -p /workspace

# Create entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /app/lobechat-source
EXPOSE 3210

ENTRYPOINT ["/entrypoint.sh"]
