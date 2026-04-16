#!/bin/bash

echo "=== Complete Database and Migration Fix ==="

# Stop all containers
echo "1. Stopping all containers..."
docker compose down

# Force remove all volumes
echo "2. Removing all volumes..."
docker volume rm ai-smart-learning-platform_postgres_data --force
docker volume rm ai-smart-learning-platform_redis_data --force
docker volume rm ai-smart-learning-platform_ollama_data --force

# Remove all images to force rebuild
echo "3. Removing backend and frontend images..."
docker rmi ai-smart-learning-platform-backend --force
docker rmi ai-smart-learning-platform-frontend --force

# Clean up any orphaned containers
echo "4. Cleaning up orphaned containers..."
docker container prune --force

# Start completely fresh
echo "5. Starting fresh services..."
docker compose up -d --build

# Wait for services to initialize
echo "6. Waiting 30 seconds for services to initialize..."
sleep 30

# Check status
echo "7. Checking container status..."
docker compose ps

# Test services
echo "8. Testing services..."
echo "Testing frontend..."
curl -I http://localhost:3200 || echo "Frontend not working"

echo "Testing backend..."
curl -I http://localhost:4200 || echo "Backend not working"

echo "Testing ollama..."
curl -I http://localhost:11435 || echo "Ollama not working"

echo "=== Fix Complete ==="
echo "If services are still not working, check logs with:"
echo "docker logs eduai-backend"
echo "docker logs eduai-frontend"
