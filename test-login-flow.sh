#!/bin/bash

# Test login flow and role-based routing
echo "🧪 Testing Login Flow and Role-Based Routing..."

# Test 1: Check if login page loads
echo "1. Testing login page..."
curl -s http://localhost:3000 | grep -q "Login" && echo " ✅ Login page loads" || echo " ❌ Login page not found"

# Test 2: Test backend login endpoint
echo "2. Testing backend login..."
LOGIN_RESPONSE=$(curl -s -X POST http://localhost:5000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "teacher4@example.com", "password": "password123"}')

if echo "$LOGIN_RESPONSE" | grep -q "accessToken"; then
    echo " ✅ Backend login works"
    echo "   Response: $LOGIN_RESPONSE"
else
    echo " ❌ Backend login failed"
    echo "   Response: $LOGIN_RESPONSE"
fi

# Test 3: Check if instructor routes exist
echo "3. Testing instructor routes..."
curl -s http://localhost:3000/instructor/dashboard | grep -q "Instructor Dashboard" && echo " ✅ Instructor dashboard route exists" || echo " ❌ Instructor dashboard not found"

# Test 4: Check if student routes exist
echo "4. Testing student routes..."
curl -s http://localhost:3000/dashboard | grep -q "Dashboard" && echo " ✅ Student dashboard route exists" || echo " ❌ Student dashboard not found"

echo ""
echo "🎯 Expected Login Flow:"
echo "  1. Open http://localhost:3000"
echo "  2. Login with instructor credentials"
echo "  3. Should redirect to /instructor/dashboard"
echo "  4. Should see instructor navigation menu"
echo ""
echo "🔐 Test Credentials:"
echo "  - Instructor: teacher4@example.com / password123"
echo "  - Student: student@example.com / password123"
echo ""
echo "🌐 If login page loads but redirects don't work:"
echo "  - Check browser console for JavaScript errors"
echo "  - Verify user role is correctly decoded from JWT"
echo "  - Check ProtectedRoute component logic"
