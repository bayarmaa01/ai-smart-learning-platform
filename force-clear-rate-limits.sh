#!/bin/bash

# Force clear rate limits completely
echo "🧹 Force Clearing All Rate Limits..."

# Stop backend completely
echo "🛑 Stopping backend..."
docker compose stop backend

# Wait for full stop
sleep 5

# Remove backend container completely (clears all memory)
echo "🗑️ Removing backend container..."
docker compose rm -f backend

# Recreate backend container
echo "🔄 Recreating backend container..."
docker compose up -d backend

# Wait for backend to fully start
echo "⏳ Waiting for backend to fully start..."
sleep 15

# Test backend health
echo "🔍 Testing backend health..."
curl -f http://localhost:5000/health 2>/dev/null && echo " ✅ Backend healthy" || echo " ❌ Backend unhealthy"

echo ""
echo "✅ Rate limits completely cleared!"
echo ""
echo "🧪 Test registration immediately:"
echo "1. Open http://localhost:3000"
echo "2. Go to registration page"
echo "3. Fill form and submit"
echo "4. Should work now (no 429 error)"
