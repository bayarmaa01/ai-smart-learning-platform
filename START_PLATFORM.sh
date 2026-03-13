#!/bin/bash

# Complete EduAI Platform Startup with All Fixes
echo "🚀 Starting EduAI Platform - Complete Setup..."

# Step 1: Stop all services
echo "⏹️  Stopping existing services..."
docker compose down

# Step 2: Kill conflicting processes
echo "🧹 Cleaning up port conflicts..."
for port in 5000 8000 5432 9000 9001; do
    if lsof -i :$port > /dev/null 2>&1; then
        echo "  Killing processes on port $port..."
        sudo lsof -ti :$port | xargs sudo kill -9 2>/dev/null || true
    fi
done

# Step 3: Clean Docker
echo "🐳 Cleaning up Docker..."
docker container prune -f
docker network prune -f

# Step 4: Initialize database
echo "🗄️ Initializing database..."
./init-database.sh

# Step 5: Start all services
echo "🚀 Starting all services..."
docker compose up -d

# Step 6: Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 60

# Step 7: Check service health
echo "🔍 Checking service health..."
docker compose ps

echo ""
echo "🎉 EduAI Platform is ready!"
echo ""
echo "🌐 Access URLs:"
echo "  📱 Frontend: http://localhost:3000"
echo "  🔧 Backend API: http://localhost:5001"
echo "  🤖 AI Service: http://localhost:8001"
echo ""
echo "📊 Monitoring & Tools:"
echo "  📈 Grafana: http://localhost:3001"
echo "  🔍 Prometheus: http://localhost:9090"
echo "  💾 MinIO Console: http://localhost:9003"
echo ""
echo "🗄️  Databases (external access):"
echo "  🐘 PostgreSQL: localhost:5433"
echo "  🔴 Redis: localhost:6379"
echo "  🔎 Elasticsearch: http://localhost:9200"
echo ""
echo "🧪 Test API:"
echo "curl -f http://localhost:5001/api/v1/health || echo '❌ Backend not healthy'"
echo "curl -f http://localhost:8001/health || echo '❌ AI Service not healthy'"
echo ""
echo "📋 View logs:"
echo "docker compose logs -f"
echo ""
echo "🛑 Stop services:"
echo "docker compose down"
echo ""
echo "📝 If backend still returns 500 errors:"
echo "  1. Check database: ./init-database.sh"
echo "  2. Restart backend: docker compose restart backend"
echo "  3. Check logs: docker compose logs backend"
