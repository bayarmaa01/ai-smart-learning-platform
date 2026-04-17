#!/bin/bash

echo "=== AI Smart Learning Platform - Redis Debug Script ==="
echo

# Check Redis containers
echo "📦 Checking Redis containers..."
docker ps --filter "name=redis" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo
echo "🔍 Testing Redis connections..."

# Test eduai-redis (correct container)
echo "Testing eduai-redis:6379..."
docker exec eduai-redis redis-cli ping 2>/dev/null && echo "✅ eduai-redis:6379 - CONNECTED" || echo "❌ eduai-redis:6379 - FAILED"

# Test secure-exam-platform-redis (wrong port)
echo "Testing secure-exam-platform-redis:6380..."
docker exec secure-exam-platform-redis redis-cli ping 2>/dev/null && echo "✅ secure-exam-platform-redis:6380 - CONNECTED" || echo "❌ secure-exam-platform-redis:6380 - FAILED"

echo
echo "🌐 Testing network connectivity from backend..."
docker exec eduai-backend ping -c 1 eduai-redis 2>/dev/null && echo "✅ Backend can reach eduai-redis" || echo "❌ Backend cannot reach eduai-redis"

echo
echo "📊 Container logs (last 10 lines)..."
echo "--- eduai-redis logs ---"
docker logs --tail 10 eduai-redis 2>/dev/null || echo "No logs available"

echo "--- backend logs (Redis errors) ---"
docker logs --tail 10 eduai-backend 2>&1 | grep -i redis || echo "No Redis errors in logs"

echo
echo "🔧 Environment variables in backend..."
docker exec eduai-backend env | grep -E "(REDIS|DB_)" | sort

echo
echo "=== Debug Complete ==="
echo "If eduai-redis shows CONNECTED but backend shows errors:"
echo "1. Check REDIS_HOST in docker-compose.yml matches 'eduai-redis'"
echo "2. Check REDIS_PORT matches '6379'"
echo "3. Restart backend: docker restart eduai-backend"
echo "4. View full logs: docker logs -f eduai-backend"
