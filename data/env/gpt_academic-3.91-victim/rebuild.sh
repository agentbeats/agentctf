#!/bin/bash
# Rebuild gpt_academic 3.91 runtime with updated dependencies

IMAGE_NAME="gpt_academic-3.91"

echo "=========================================="
echo "Rebuilding ${IMAGE_NAME} Docker image"
echo "=========================================="
echo ""
echo "This will install additional dependencies:"
echo "  - requests (required by arxiv download module)"
echo "  - beautifulsoup4 (required by arxiv download module)"
echo ""

# Remove old image
echo "[1/2] Removing old image..."
sudo docker rmi ${IMAGE_NAME}:latest 2>/dev/null || echo "No old image to remove"

# Build new image
echo "[2/2] Building new image..."
sudo docker build --no-cache -t ${IMAGE_NAME}:latest .

echo ""
echo "=========================================="
echo "Rebuild complete!"
echo "=========================================="
