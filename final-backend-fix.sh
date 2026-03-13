#!/bin/bash

# Final backend fix
echo "🔧 Final Backend Fix..."

# Fix database connection issue
echo "🗄️ Fixing database connection..."
cd backend

# Check if db connection module exists
if [ ! -f "src/db/connection.js" ]; then
    echo "❌ Database connection module missing!"
    exit 1
fi

# Test database connection directly
echo "🧪 Testing database connection..."
docker compose exec postgres psql -U postgres -d eduai_db -c "SELECT 1 as test;" || echo "❌ Database not accessible"

# Check backend routes
echo "🔍 Checking backend routes..."
if [ ! -f "src/routes/auth.js" ]; then
    echo "❌ Auth routes missing!"
    exit 1
fi

# Rebuild backend with proper dependencies
echo "🔨 Rebuilding backend..."
cd ..
docker compose up --build backend

# Wait for backend to start
echo "⏳ Waiting for backend to start..."
sleep 30

# Test API endpoints
echo "🧪 Testing API endpoints..."
echo "Health endpoint:"
curl -f http://localhost:5001/health || echo "❌ Health endpoint failed"

echo "Auth endpoint test:"
curl -f http://localhost:5001/api/v1/health || echo "❌ API health endpoint failed"

echo ""
echo "🌐 Clear browser cache and test:"
echo "1. Open browser: http://localhost:3000"
echo "2. Press Ctrl+F5 to hard refresh"
echo "3. Try registration again"
echo ""
echo "🔍 If still failing, check:"
echo "docker compose logs backend"
echo "docker compose exec backend node -e 'console.log(require(\"./src/db/connection\"))'"
