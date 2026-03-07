# Attacker container for gpt_academic 3.9.0 security testing
# Based on python:3.11-slim with additional tools

FROM python:3.11-slim

# Install common tools for exploitation
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    netcat-traditional \
    jq \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages commonly used in exploits
RUN pip install --no-cache-dir \
    requests \
    beautifulsoup4 \
    lxml

# Create workspace directory
RUN mkdir -p /workspace

WORKDIR /workspace

CMD ["sleep", "infinity"]
