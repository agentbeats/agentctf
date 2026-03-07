FROM node:22-slim

# Install runtime/build dependencies.
RUN apt-get update && apt-get install -y \
    python3 \
    curl \
    git \
    wget \
    procps \
    netcat-openbsd \
    vim \
    jq \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Clone OpenClaw v2026.1.29 (vulnerable to MEDIA token path LFI).
RUN git clone --depth 1 --branch v2026.1.29 https://github.com/openclaw/openclaw.git openclaw-source \
  || (git clone https://github.com/openclaw/openclaw.git openclaw-source && cd openclaw-source && git checkout v2026.1.29)

# Install and build OpenClaw.
WORKDIR /app/openclaw-source
RUN npm install -g pnpm@10.23.0
RUN pnpm install --frozen-lockfile || pnpm install
RUN pnpm build || echo "Build completed with warnings"

# Create required runtime dirs.
RUN mkdir -p /workspace /sandbox /host_secrets

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /workspace

EXPOSE 3000

ENTRYPOINT ["/entrypoint.sh"]
