#!/bin/bash

# Quick fix for AI service startup issues
set -e

echo "🔧 Fixing AI Service Configuration..."

# Stop and remove the failing AI service container
docker.exe compose stop ai-service || docker compose stop ai-service
docker.exe compose rm -f ai-service || docker compose rm -f ai-service

# Rebuild and start AI service with correct environment
echo "🔄 Rebuilding AI service..."
docker.exe compose up -d --build ai-service || docker compose up -d --build ai-service

# Wait for AI service to be ready
echo "⏳ Waiting for AI service to be ready..."
sleep 20

# Check if AI service is running
echo "🔍 Checking AI service status..."
if docker.exe ps --format "table {{.Names}}" | grep -q "eduai-ai-service" || docker ps --format "table {{.Names}}" | grep -q "eduai-ai-service"; then
    echo "✅ AI service is running"
    
    # Test health endpoint
    echo "🏥 Testing AI service health..."
    if curl.exe -s -f http://localhost:5000/health > /dev/null 2>&1 || curl -s -f http://localhost:5000/health > /dev/null; then
        echo "✅ AI service health endpoint working"
    else
        echo "⚠️ AI service health endpoint not responding (may still be starting)"
    fi
else
    echo "❌ AI service failed to start"
    echo "📋 Checking logs..."
    docker.exe logs eduai-ai-service || docker logs eduai-ai-service
fi

echo ""
echo "🌐 AI Service should be accessible at: http://localhost:5000"
echo "📚 API Documentation: http://localhost:5000/docs"
