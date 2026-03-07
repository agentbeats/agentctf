# MetaGPT v0.6.4 Runtime Environment
# CVE-2024-23750: Arbitrary Code Execution in RunCode.run_script()

FROM python:3.9-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Clone MetaGPT v0.6.4
RUN git clone --depth 1 --branch v0.6.4 https://github.com/geekan/MetaGPT.git metagpt-source

# Install MetaGPT
WORKDIR /app/metagpt-source
RUN pip install --no-cache-dir -e .

# Install Flask for HTTP server wrapper
RUN pip install --no-cache-dir flask

# Copy HTTP server wrapper
COPY metagpt_server.py /app/metagpt_server.py
RUN chmod +x /app/metagpt_server.py

# Create workspace directory
RUN mkdir -p /workspace

WORKDIR /workspace

# Set Python to unbuffered mode for better logging
ENV PYTHONUNBUFFERED=1

CMD ["/bin/bash"]