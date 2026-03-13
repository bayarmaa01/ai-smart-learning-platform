#!/bin/bash

# Final port fix - kill conflicts and restart
echo "🔧 Final Port Fix..."

# Kill all conflicting processes
echo "🧹 Killing all conflicting processes..."
for port in 5000 8000 5432 9000; do
    if lsof -i :$port > /dev/null 2>&1; then
        echo "  Killing processes on port $port..."
        sudo lsof -ti :$port | xargs sudo kill -9 2>/dev/null || true
    fi
done

# Wait for ports to clear
echo "⏳ Waiting for ports to clear..."
sleep 5

# Stop all containers
echo "⏹️  Stopping all containers..."
docker compose down

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

# Test endpoints
echo "🧪 Testing endpoints..."
echo "Backend health:"
curl -f http://localhost:5000/health 2>/dev/null && echo " ✅" || echo " ❌"

echo "API health:"
curl -f http://localhost:5000/api/v1/health 2>/dev/null && echo " ✅" || echo " ❌"

echo "AI service:"
curl -f http://localhost:8000/health 2>/dev/null && echo " ✅" || echo " ❌"

echo ""
echo "🎉 Platform should be running!"
echo ""
echo "🌐 Access URLs:"
echo "  📱 Frontend: http://localhost:3000"
echo "  🔧 Backend API: http://localhost:5000"
echo "  🤖 AI Service: http://localhost:8000"
echo ""
echo "🔍 If backend still returns 500:"
echo "  docker compose logs backend"
echo "  docker compose restart backend"
echo ""
echo "📱 Test in browser:"
echo "  1. Open http://localhost:3000"
echo "  2. Try registering"
