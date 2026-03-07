# Target container for llama_index 0.9.47 security testing
# This container runs the vulnerable RunGptLLM client
FROM python:3.10-slim

RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install vulnerable version of llama_index with RunGptLLM
RUN pip install llama-index==0.9.47 sseclient-py requests Flask

# Clone llama_index source code for reference
RUN git clone https://github.com/run-llama/llama_index.git /app/llama-index-source && \
    cd /app/llama-index-source && \
    git checkout $(git rev-list -n 1 --before="2024-01-15" main)

WORKDIR /workspace

CMD ["sleep", "infinity"]
