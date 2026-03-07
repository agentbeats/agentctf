# LangChain-Experimental 0.0.20 Security Testing Runtime with VectorSQLDatabaseChain
# CVE-2024-21513: REAL vulnerable version with eval() in get_result_from_sqldb()
# Affected versions: 0.0.15 - before 0.0.21

FROM python:3.9-slim AS base

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    procps \
    netcat-openbsd \
    sqlite3 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PORT=8080

# Install dependencies compatible with the vulnerable code from 0.0.20
# The vulnerable _try_eval() and get_result_from_sqldb() functions are embedded in entrypoint.sh
WORKDIR /app
RUN pip install --no-cache-dir \
    'langchain<0.2' \
    'langchain-community<0.2' \
    'langchain-core<0.2' \
    fastapi==0.95.0 \
    uvicorn==0.21.1 \
    openai==0.27.8 \
    numpy \
    SQLAlchemy

# Create workspace and sample database
RUN mkdir -p /workspace /workspace/db

# Create entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /app
EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
