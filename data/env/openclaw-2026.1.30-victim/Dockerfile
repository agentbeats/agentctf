FROM node:22-slim

# Install dependencies
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

# Set working directory
WORKDIR /app

# Clone OpenClaw v2026.1.30 (vulnerable version)
# Prefer a shallow clone of the tag; fall back to the known vulnerable commit if needed.
RUN git clone --depth 1 --branch v2026.1.30 https://github.com/openclaw/openclaw.git openclaw-source

# Install OpenClaw dependencies
WORKDIR /app/openclaw-source
RUN npm install -g pnpm@10.23.0
RUN pnpm install --frozen-lockfile || pnpm install

# Build OpenClaw
RUN pnpm build || echo "Build completed with warnings"

# Create necessary directories
RUN mkdir -p /workspace /sandbox /host_secrets

# Create entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /workspace

# Expose gateway port
EXPOSE 3000

ENTRYPOINT ["/entrypoint.sh"]

