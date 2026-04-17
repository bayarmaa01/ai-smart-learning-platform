#!/bin/bash

echo "=== Fixing Frontend Connection Issues ==="

# Stop frontend container
echo "1. Stopping frontend container..."
docker compose stop frontend

# Remove frontend container and image
echo "2. Removing frontend container and image..."
docker rmi ai-smart-learning-platform-frontend --force

# Rebuild frontend from scratch
echo "3. Rebuilding frontend from scratch..."
docker compose build --no-cache frontend

# Start frontend
echo "4. Starting frontend..."
docker compose up -d frontend

# Wait for container to start
echo "5. Waiting 10 seconds for container to initialize..."
sleep 10

# Test frontend
echo "6. Testing frontend access..."
curl -I http://localhost:3200

# Check container logs
echo "7. Checking container logs..."
docker logs eduai-frontend --tail 20

echo "=== Frontend Fix Complete ==="
