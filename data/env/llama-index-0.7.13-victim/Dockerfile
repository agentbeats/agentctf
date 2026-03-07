# Llama Index 0.7.13 Security Testing Runtime
# Full llama_index source code with vulnerable PandasQueryEngine

FROM python:3.9-slim AS base

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    procps \
    netcat-openbsd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PORT=8080

# Clone llama_index 0.7.13 source code (corresponds to v0.7.13)
WORKDIR /app
RUN git clone --depth 1 --branch v0.7.13 https://github.com/jerryjliu/llama_index.git llama-index-source

# Install llama_index and dependencies from source
WORKDIR /app/llama-index-source
# Install compatible versions with pydantic v1 for FastAPI
RUN pip install --no-cache-dir \
    numpy==1.24.3 \
    pandas==2.0.3 \
    openai==0.27.6 \
    "pydantic>=1.10,<2.0" \
    fastapi==0.95.0 \
    uvicorn==0.21.1 \
    starlette==0.26.1 \
    tiktoken \
    dataclasses_json \
    "langchain==0.0.247" \
    "sqlalchemy>=2.0.15" \
    "tenacity>=8.2.0,<9.0.0" \
    "urllib3<2" \
    "fsspec>=2023.5.0" \
    "typing-inspect>=0.8.0" \
    "typing_extensions>=4.5.0" \
    beautifulsoup4 \
    nest_asyncio

# Install llama_index without dependencies to avoid conflicts
RUN pip install --no-cache-dir --no-deps -e .

# Create workspace for test scripts
RUN mkdir -p /workspace

# Create entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /app/llama-index-source
EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
