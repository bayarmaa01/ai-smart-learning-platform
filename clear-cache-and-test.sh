#!/bin/bash

# Clear all caches and test
echo "🧹 Clearing All Caches and Testing..."

# Restart frontend to force cache clear
echo "🔄 Restarting frontend..."
docker compose restart frontend

# Wait for frontend
sleep 10

# Test API endpoints directly
echo "🧪 Testing API endpoints..."
echo "1. Testing /health:"
curl -s http://localhost:5001/health | jq '.' || echo "Failed"

echo "2. Testing /api/v1/health:"
curl -s http://localhost:5001/api/v1/health | jq '.' || echo "Failed"

echo "3. Testing registration:"
curl -s -X POST http://localhost:5001/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"email":"test3@example.com","password":"Test123!","firstName":"Test3","lastName":"User"}' \
  -w "\nHTTP Status: %{http_code}\n" || echo "Failed"

echo ""
echo "🌐 Browser Testing Instructions:"
echo "1. Open browser: http://localhost:3000"
echo "2. Open Developer Tools (F12)"
echo "3. Right-click refresh button → 'Empty Cache and Hard Reload'"
echo "4. Or press: Ctrl+Shift+R (hard refresh)"
echo "5. Go to Network tab"
echo "6. Check that requests go to: localhost:5001 (not 5000)"
echo "7. Try registering a new user"
echo ""
echo "🔍 If still seeing port 5000 in browser:"
echo "   - The frontend build didn't include the new .env file"
echo "   - Try: docker compose up --build frontend"
echo "   - Or: Clear browser data completely"
echo ""
echo "📊 Current Service Status:"
docker compose ps
