# DB-GPT v0.7.0 Runtime Environment
# CVE-2025-51458: SQL Injection in SQL Editor Endpoints
# CVE-2025-51459: RCE via Plugin Upload
# CVE-2025-6772: Path Traversal via Flow Import
# This runs the REAL DB-GPT server with vulnerable endpoints

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
    sqlite3 \
    && rm -rf /var/lib/apt/lists/*

# Clone DB-GPT v0.7.0
RUN git clone --depth 1 --branch v0.7.0 https://github.com/eosphoros-ai/DB-GPT.git dbgpt-source

WORKDIR /app/dbgpt-source

# Upgrade pip and install build tools
RUN pip install --no-cache-dir --upgrade pip setuptools wheel

# Install SQLAlchemy and other core dependencies
RUN pip install --no-cache-dir \
    sqlalchemy \
    sqlparse \
    fastapi \
    uvicorn[standard] \
    pydantic \
    requests \
    python-multipart \
    aiofiles \
    pymysql \
    cloudpickle \
    httpx \
    aiosqlite

# Install core packages with necessary extras
RUN pip install --no-cache-dir -e "packages/dbgpt-core/[simple_framework]" || echo "dbgpt-core install had issues (continuing)"
RUN pip install --no-cache-dir -e packages/dbgpt-client/ || echo "dbgpt-client install had issues (continuing)"
RUN pip install --no-cache-dir -e packages/dbgpt-ext/ || echo "dbgpt-ext install had issues (continuing)"
RUN pip install --no-cache-dir -e packages/dbgpt-serve/ || echo "dbgpt-serve install had issues (continuing)"
RUN pip install --no-cache-dir -e packages/dbgpt-app/ || echo "dbgpt-app install had issues (continuing)"

# Create necessary directories
RUN mkdir -p /app/plugins /workspace /tmp

# Create entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /workspace

# Expose DB-GPT API port
EXPOSE 5670

# Set Python to unbuffered mode
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

ENTRYPOINT ["/entrypoint.sh"]
