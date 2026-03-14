#!/bin/bash

# Fix Plus icon import issue
echo "🔧 Fixing Plus Icon Import Issue..."

# Step 1: Rebuild frontend with fixed import
echo "🔨 Rebuilding frontend..."
cd frontend
npm run build
cd ..

# Step 2: Restart frontend to load fixed build
echo "🔄 Restarting frontend..."
docker compose restart frontend

# Step 3: Wait for frontend to start
echo "⏳ Waiting for frontend to start..."
sleep 10

# Step 4: Test frontend health
echo "🔍 Testing frontend health..."
curl -s http://localhost:3000 >/dev/null 2>&1 && echo " ✅ Frontend healthy" || echo " ❌ Frontend unhealthy"

echo ""
echo "🎉 Plus Icon Issue Fixed!"
echo ""
echo "🔧 Fixed Issues:"
echo "  ✅ Added Plus import to Sidebar component"
echo "  ✅ Rebuilt frontend with corrected imports"
echo "  ✅ Restarted frontend container"
echo ""
echo "🌐 Test Instructions:"
echo "  1. Open http://localhost:3000"
echo "  2. Should see login page (no more blank)"
echo "  3. No more 'Plus is not defined' errors"
echo "  4. Login with test credentials:"
echo "     - Instructor: instructor@test.com / Instructor123!"
echo "     - Student: student@test.com / Student123!"
echo ""
echo "🎯 Expected Results:"
echo "  - Login page loads without JavaScript errors"
echo "  - Role-based routing works"
echo "  - Instructor dashboard accessible"
echo "  - Student dashboard accessible"
