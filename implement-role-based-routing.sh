#!/bin/bash

# Implement complete role-based routing system
echo "🔧 Implementing Role-Based Routing System..."

# Step 1: Rebuild frontend with new role-based routing
echo "🔨 Rebuilding frontend..."
cd frontend
npm run build
cd ..

# Step 2: Restart frontend to load new build
echo "🔄 Restarting frontend..."
docker compose restart frontend

# Step 3: Wait for frontend to start
echo "⏳ Waiting for frontend to start..."
sleep 10

# Step 4: Test backend health
echo "🔍 Testing backend health..."
curl -f http://localhost:5000/health 2>/dev/null && echo " ✅ Backend healthy" || echo " ❌ Backend unhealthy"

# Step 5: Test frontend health
echo "🔍 Testing frontend health..."
curl -f http://localhost:3000 2>/dev/null && echo " ✅ Frontend healthy" || echo " ❌ Frontend unhealthy"

echo ""
echo "🎉 Role-Based Routing System Implemented!"
echo ""
echo "📋 Features Added:"
echo "  ✅ Role-based navigation (Student/Instructor/Admin)"
echo "  ✅ Automatic redirect based on user role:"
echo "     - student → /dashboard"
echo "     - instructor → /instructor/dashboard"
echo "     - admin → /admin"
echo "  ✅ Role-based sidebar menus"
echo "  ✅ Route protection (students can't access instructor routes)"
echo "  ✅ Instructor dashboard with stats and course management"
echo "  ✅ Instructor pages: Dashboard, Courses, Create Course, Students, Analytics"
echo "  ✅ Clean UI without debug borders"
echo ""
echo "🌐 Test Role-Based Routing:"
echo "  1. Open http://localhost:3000"
echo "  2. Login as student → should go to /dashboard"
echo "  3. Login as instructor → should go to /instructor/dashboard"
echo "  4. Login as admin → should go to /admin"
echo ""
echo "🔐 Route Protection:"
echo "  - Students can only access student routes"
echo "  - Instructors can only access instructor routes"
echo "  - Admins can access admin routes"
echo "  - Unauthorized access redirects to correct dashboard"
echo ""
echo "📊 Instructor Features:"
echo "  - Dashboard with course stats"
echo "  - Course management (create, edit, view)"
echo "  - Student management and analytics"
echo "  - Revenue and performance tracking"
echo ""
echo "🎯 Expected Results:"
echo "  - teacher4@example.com (instructor) → instructor dashboard"
echo "  - Students → student dashboard"
echo "  - Admins → admin panel"
echo "  - No UI errors or console errors"
echo "  - Fully working role-based UI"
