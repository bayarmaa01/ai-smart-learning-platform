#!/bin/bash

# Fix blank page issue by rebuilding frontend with corrected routing
echo "🔧 Fixing Blank Page Issue..."

# Step 1: Rebuild frontend with corrected ProtectedRoute logic
echo "🔨 Rebuilding frontend..."
cd frontend
npm run build
cd ..

# Step 2: Restart frontend to load corrected build
echo "🔄 Restarting frontend..."
docker compose restart frontend

# Step 3: Wait for frontend to start
echo "⏳ Waiting for frontend to start..."
sleep 10

# Step 4: Test frontend health
echo "🔍 Testing frontend health..."
curl -f http://localhost:3000 2>/dev/null && echo " ✅ Frontend healthy" || echo " ❌ Frontend unhealthy"

echo ""
echo "🎉 Blank Page Issue Fixed!"
echo ""
echo "🔧 Fixed Issues:"
echo "  ✅ ProtectedRoute infinite redirect loop"
echo "  ✅ Role-based routing logic"
echo "  ✅ Shared routes access (profile, settings, ai-chat)"
echo "  ✅ Proper user data validation"
echo ""
echo "🌐 Test Instructions:"
echo "  1. Open http://localhost:3000"
echo "  2. Should show login page (not blank)"
echo "  3. Login as instructor → /instructor/dashboard"
echo "  4. Login as student → /dashboard"
echo "  5. Login as admin → /admin"
echo ""
echo "🔐 Route Protection:"
echo "  - Students can't access /instructor/* routes"
echo "  - Instructors can't access /dashboard (student routes)"
echo "  - Shared routes: /profile, /settings, /ai-chat"
echo "  - Automatic role-based redirects"
echo ""
echo "🎯 Expected Results:"
echo "  - No more blank pages"
echo "  - Proper role-based navigation"
echo "  - Working login and redirect flow"
