#!/bin/bash

# Debug backend issues
echo "🔍 Debugging Backend Service..."

# Check if backend container is running
echo "📊 Backend Container Status:"
docker compose ps backend

echo ""
echo "🔍 Backend Health Check:"
docker compose exec backend curl -f http://localhost:5000/health || echo "❌ Backend health check failed"

echo ""
echo "📋 Backend Logs (last 20 lines):"
docker compose logs --tail=20 backend

echo ""
echo "🗄️ Database Connection Test:"
docker compose exec backend node -e "
const { query } = require('./src/db/connection');
query('SELECT 1 as test').then(result => {
  console.log('✅ Database connection successful:', result.rows[0]);
  process.exit(0);
}).catch(err => {
  console.log('❌ Database connection failed:', err.message);
  process.exit(1);
});
" 2>/dev/null || echo "❌ Could not test database connection"

echo ""
echo "🧪 Direct API Test:"
curl -f http://localhost:5001/api/v1/health || echo "❌ API not accessible from host"

echo ""
echo "🔧 If backend is unhealthy:"
echo "  1. Restart: docker compose restart backend"
echo "  2. Rebuild: docker compose up --build backend"
echo "  3. Check database: ./init-database.sh"
echo "  4. View full logs: docker compose logs -f backend"
