#!/bin/bash

# Final fix for all port conflicts and service startup
echo "🔧 Final EduAI Platform Fix..."

# Stop all services
echo "⏹️  Stopping all services..."
docker compose down

# Kill any remaining processes on conflicting ports
echo "🧹 Cleaning up port conflicts..."
for port in 5432 9000; do
    if lsof -i :$port > /dev/null 2>&1; then
        echo "  Killing processes on port $port..."
        sudo lsof -ti :$port | xargs sudo kill -9 2>/dev/null || true
    fi
done

# Clean up Docker
echo "🐳 Cleaning up Docker..."
docker container prune -f
docker network prune -f

# Start services
echo "🚀 Starting all services..."
docker compose up -d

# Wait for services
echo "⏳ Waiting for services to start..."
sleep 45

# Check status
echo "📊 Service Status:"
docker compose ps

echo ""
echo "🎉 EduAI Platform is starting up!"
echo ""
echo "🌐 Access the platform:"
echo "  📱 Frontend: http://localhost:3000"
echo "  🔧 Backend API: http://localhost:5000"
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
echo "📋 Check logs:"
echo "docker compose logs -f"
echo ""
echo "🛑 Stop services:"
echo "docker compose down"
