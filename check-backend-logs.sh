#!/bin/bash

# Check backend logs and fix issues
echo "🔍 Checking Backend Issues..."

echo "📋 Backend Container Status:"
docker compose ps backend

echo ""
echo "📋 Backend Logs (last 30 lines):"
docker compose logs --tail=30 backend

echo ""
echo "🗄️ Database Connection Test:"
docker compose exec postgres psql -U postgres -d eduai_db -c "SELECT 1 as test;" 2>/dev/null || echo "❌ Database not accessible"

echo ""
echo "🧪 Direct Backend Test:"
docker compose exec backend curl -f http://localhost:5000/health 2>/dev/null || echo "❌ Backend not responding internally"

echo ""
echo "🔧 Restart backend if needed:"
echo "docker compose restart backend"

echo ""
echo "🏗️ Rebuild backend if needed:"
echo "docker compose up --build backend"
