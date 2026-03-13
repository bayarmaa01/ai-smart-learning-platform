#!/bin/bash

# Rebuild AI Service with optimized settings
echo "🔧 Rebuilding AI Service..."

# Clean up any existing containers/images
docker compose down ai-service 2>/dev/null || true
docker rmi ai-smart-learning-platform-ai-service 2>/dev/null || true

# Build with optimizations
docker compose build ai-service --no-cache --progress=plain

echo "✅ AI Service build complete!"
echo ""
echo "🚀 To start all services:"
echo "docker compose up -d"
echo ""
echo "🔍 To check logs:"
echo "docker compose logs -f ai-service"
