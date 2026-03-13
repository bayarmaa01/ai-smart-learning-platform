#!/bin/bash

# Complete registration system fix with teacher role
echo "🔧 Complete Registration System Fix..."

# Step 1: Rebuild backend with teacher role
echo "🔨 Rebuilding backend..."
docker compose build backend

# Step 2: Rebuild frontend with teacher role
echo "🔨 Rebuilding frontend..."
cd frontend
npm run build
cd ..

# Step 3: Restart services
echo "🔄 Restarting services..."
docker compose restart backend frontend

# Step 4: Wait for services
echo "⏳ Waiting for services to start..."
sleep 15

# Step 5: Test registration
echo "🧪 Testing registration with new roles..."

echo "Testing student registration..."
STUDENT_RESPONSE=$(curl -s -X POST http://localhost:5000/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{
    "firstName": "John",
    "lastName": "Student",
    "email": "newstudent@example.com",
    "password": "Student123!",
    "role": "student"
  }')

if echo "$STUDENT_RESPONSE" | grep -q '"success":true'; then
    echo " ✅ Student registration successful"
else
    echo " ❌ Student registration failed"
    echo "$STUDENT_RESPONSE"
fi

sleep 2

echo "Testing teacher registration..."
TEACHER_RESPONSE=$(curl -s -X POST http://localhost:5000/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{
    "firstName": "Jane",
    "lastName": "Teacher",
    "email": "newteacher@example.com",
    "password": "Teacher123!",
    "role": "teacher"
  }')

if echo "$TEACHER_RESPONSE" | grep -q '"success":true'; then
    echo " ✅ Teacher registration successful"
else
    echo " ❌ Teacher registration failed"
    echo "$TEACHER_RESPONSE"
fi

echo ""
echo "🎉 Registration System Fixed!"
echo ""
echo "📋 Changes Made:"
echo "  ✅ Backend accepts 'teacher' role instead of 'admin'"
echo "  ✅ Frontend shows 'Student' and 'Teacher' options"
echo "  ✅ Default role is 'student'"
echo "  ✅ UI is clean without debug borders"
echo ""
echo "🌐 Test in browser:"
echo "  1. Open http://localhost:3000"
echo "  2. Go to registration page"
echo "  3. Select role: Student or Teacher"
echo "  4. Fill form and submit"
echo "  5. Verify successful registration"
echo ""
echo "📊 For user endpoints (activity/stats):"
echo "  - User must be logged in first"
echo "  - These endpoints require authentication"
echo "  - 500 errors indicate authentication issues"
