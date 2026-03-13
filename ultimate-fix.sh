#!/bin/bash

# Ultimate fix for all port conflicts and service startup
echo "🔧 Ultimate EduAI Platform Fix..."

# Stop all services
echo "⏹️  Stopping all services..."
docker compose down

# Kill any remaining processes on ALL conflicting ports
echo "🧹 Cleaning up ALL port conflicts..."
for port in 5000 8000 5432 9000 9001; do
    if lsof -i :$port > /dev/null 2>&1; then
        echo "  Killing processes on port $port..."
        sudo lsof -ti :$port | xargs sudo kill -9 2>/dev/null || true
    fi
done

# Wait for ports to be released
echo "⏳ Waiting for ports to be released..."
sleep 5

# Clean up Docker completely
echo "🐳 Cleaning up Docker..."
docker container prune -f
docker network prune -f
docker volume prune -f

# Start services
echo "🚀 Starting all services..."
docker compose up -d

# Wait for services
echo "⏳ Waiting for services to start..."
sleep 60

# Check status
echo "📊 Service Status:"
docker compose ps

echo ""
echo "🎉 EduAI Platform is starting up!"
echo ""
echo "🌐 FINAL Access URLs:"
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
echo "  💾 MinIO API: http://localhost:9002"
echo ""
echo "📋 Check logs:"
echo "docker compose logs -f"
echo ""
echo "🛑 Stop services:"
echo "docker compose down"
echo ""
echo "✨ If you still have issues, check:"
echo "  - Docker Desktop is running"
echo "  - No other services are using ports 3000, 5001, 8001, 5433, 9002, 9003"
echo "  - System has enough RAM (recommended 8GB+)"
