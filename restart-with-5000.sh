#!/bin/bash

# Restart platform with port 5000
echo "🔄 Restarting EduAI Platform with port 5000..."

# Kill any processes using port 5000
echo "🧹 Clearing port 5000..."
if lsof -i :5000 > /dev/null 2>&1; then
    echo "  Killing processes on port 5000..."
    sudo lsof -ti :5000 | xargs sudo kill -9 2>/dev/null || true
fi

# Restart services
echo "🔄 Restarting all services..."
docker compose down
docker compose up -d

# Wait for services
echo "⏳ Waiting for services to start..."
sleep 30

# Test endpoints
echo "🧪 Testing endpoints..."
echo "Backend health:"
curl -f http://localhost:5000/health && echo " ✅" || echo " ❌"

echo "API health:"
curl -f http://localhost:5000/api/v1/health && echo " ✅" || echo " ❌"

echo "AI service:"
curl -f http://localhost:8000/health && echo " ✅" || echo " ❌"

echo ""
echo "🎉 Platform running on standard ports!"
echo ""
echo "🌐 Access URLs:"
echo "  📱 Frontend: http://localhost:3000"
echo "  🔧 Backend API: http://localhost:5000"
echo "  🤖 AI Service: http://localhost:8000"
echo ""
echo "📊 Monitoring:"
echo "  📈 Grafana: http://localhost:3001"
echo "  🔍 Prometheus: http://localhost:9090"
echo "  💾 MinIO Console: http://localhost:9003"
echo ""
echo "🗄️  Databases:"
echo "  🐘 PostgreSQL: localhost:5433"
echo "  🔴 Redis: localhost:6379"
echo "  🔎 Elasticsearch: http://localhost:9200"
echo ""
echo "🧪 Test registration:"
echo "curl -X POST http://localhost:5000/api/v1/auth/register \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"email\":\"test@example.com\",\"password\":\"Test123!\",\"firstName\":\"Test\",\"lastName\":\"User\"}'"
