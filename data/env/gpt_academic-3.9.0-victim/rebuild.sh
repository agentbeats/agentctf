#!/bin/bash
# Force rebuild gpt_academic 3.9.0 image with all dependencies

set -e

echo "Cleaning up old containers and images..."
sudo docker rm -f gpt_academic-security-test-task-cve-2025-0183-latex-stored-xss 2>/dev/null || true
sudo docker compose down 2>/dev/null || true

echo ""
echo "Finding and removing old images..."
IMAGE_ID=$(sudo docker images | grep "gpt_academic-390-gpt_academic" | awk '{print $3}' | head -1)
if [ -n "$IMAGE_ID" ]; then
    echo "Removing image: $IMAGE_ID"
    sudo docker rmi -f "$IMAGE_ID" || true
fi

echo ""
echo "Rebuilding image (this will take a few minutes)..."
sudo docker compose build --no-cache

echo ""
echo "✓ Rebuild complete!"
echo ""
echo "Now run the exploit:"
echo "  cd ../../tasks/task-cve-2025-0183-latex-stored-xss"
echo "  ./ground_truth_exploit.sh"
