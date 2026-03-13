#!/bin/bash

# Complete fix for all platform issues
echo "🚀 COMPLETE EduAI Platform Fix..."

# Step 1: Restart backend with new health endpoint
echo "🔄 Restarting backend with new health endpoint..."
docker compose restart backend

# Step 2: Wait for backend
echo "⏳ Waiting for backend to start..."
sleep 10

# Step 3: Test both health endpoints
echo "🧪 Testing health endpoints..."
echo "Testing /health:"
curl -f http://localhost:5001/health && echo " ✅ /health working" || echo " ❌ /health failed"

echo "Testing /api/v1/health:"
curl -f http://localhost:5001/api/v1/health && echo " ✅ /api/v1/health working" || echo " ❌ /api/v1/health failed"

# Step 4: Test registration endpoint
echo "🧪 Testing registration endpoint..."
curl -X POST http://localhost:5001/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"email":"test@example.com","password":"Test123!","firstName":"Test","lastName":"User"}' \
  -w "\nStatus: %{http_code}\n" || echo " ❌ Registration failed"

# Step 5: Clear frontend cache and restart
echo "🔄 Restarting frontend to clear cache..."
docker compose restart frontend

echo ""
echo "🎉 COMPLETE FIX APPLIED!"
echo ""
echo "🌐 Platform URLs:"
echo "  📱 Frontend: http://localhost:3000"
echo "  🔧 Backend API: http://localhost:5001"
echo "  🤖 AI Service: http://localhost:8001"
echo ""
echo "🧪 Test Commands:"
echo "  Health: curl http://localhost:5001/api/v1/health"
echo "  Register: curl -X POST http://localhost:5001/api/v1/auth/register \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"email\":\"test@example.com\",\"password\":\"Test123!\",\"firstName\":\"Test\",\"lastName\":\"User\"}'"
echo ""
echo "🔍 If still having issues:"
echo "  1. Clear browser cache (Ctrl+F5)"
echo "  2. Check browser network tab for actual URLs"
echo "  3. View logs: docker compose logs -f backend"
echo "  4. Check frontend: docker compose logs -f frontend"
echo ""
echo "📱 Browser Testing:"
echo "  1. Open http://localhost:3000"
echo "  2. Press Ctrl+F5 to hard refresh"
echo "  3. Open DevTools (F12)"
echo "  4. Go to Network tab"
echo "  5. Try registering"
echo "  6. Check that requests go to port 5001, not 5000"
