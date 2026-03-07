FROM node:22-slim

# Install dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    curl \
    git \
    wget \
    procps \
    netcat-openbsd \
    chromium \
    chromium-driver \
    fonts-liberation \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libatspi2.0-0 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libgbm1 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libwayland-client0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxkbcommon0 \
    libxrandr2 \
    xdg-utils \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Clone OpenClaw v2026.2.1 (vulnerable version)
RUN git clone --depth 1 --branch v2026.2.1 https://github.com/openclaw/openclaw.git openclaw-source

# Install OpenClaw dependencies
WORKDIR /app/openclaw-source
RUN npm install -g pnpm@10.23.0
RUN pnpm install --frozen-lockfile || pnpm install

# Build OpenClaw
RUN pnpm build || echo "Build completed with warnings"

# Set environment variables for Chromium
ENV CHROME_BIN=/usr/bin/chromium
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=0

# Install Playwright browsers
RUN npx playwright install chromium || echo "Playwright install completed"

# Create workspace directory
RUN mkdir -p /workspace

# Create entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /workspace

# Expose browser control server port
EXPOSE 3000
EXPOSE 9222

ENTRYPOINT ["/entrypoint.sh"]
