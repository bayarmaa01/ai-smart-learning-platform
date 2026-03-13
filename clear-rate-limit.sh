#!/bin/bash

# Clear rate limits and test registration
echo "🧹 Clearing Rate Limits..."

# Restart backend to clear rate limits
echo "🔄 Restarting backend to clear rate limits..."
docker compose restart backend

# Wait for backend to start
echo "⏳ Waiting for backend to start..."
sleep 10

# Test backend health
echo "🔍 Testing backend health..."
curl -f http://localhost:5000/health 2>/dev/null && echo " ✅ Backend healthy" || echo " ❌ Backend unhealthy"

echo ""
echo "✅ Rate limits cleared! Ready for testing."
echo ""
echo "🧪 Now run: ./test-registration-fix.sh"
