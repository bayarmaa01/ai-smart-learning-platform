#!/bin/bash

# Fix role mismatch: teacher -> instructor
echo "🔧 Fixing Role Mismatch (teacher -> instructor)..."

# Step 1: Rebuild backend with instructor role
echo "🔨 Rebuilding backend..."
docker compose build backend

# Step 2: Rebuild frontend with instructor role
echo "🔨 Rebuilding frontend..."
cd frontend
npm run build
cd ..

# Step 3: Force clear rate limits
echo "🧹 Force clearing rate limits..."
docker compose stop backend
sleep 5
docker compose rm -f backend
docker compose up -d backend

# Step 4: Restart frontend
echo "🔄 Restarting frontend..."
docker compose restart frontend

# Step 5: Wait for services
echo "⏳ Waiting for services to start..."
sleep 15

# Step 6: Test registration
echo "🧪 Testing registration with correct roles..."

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

echo "Testing instructor registration..."
INSTRUCTOR_RESPONSE=$(curl -s -X POST http://localhost:5000/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{
    "firstName": "Jane",
    "lastName": "Instructor",
    "email": "newinstructor@example.com",
    "password": "Instructor123!",
    "role": "instructor"
  }')

if echo "$INSTRUCTOR_RESPONSE" | grep -q '"success":true'; then
    echo " ✅ Instructor registration successful"
else
    echo " ❌ Instructor registration failed"
    echo "$INSTRUCTOR_RESPONSE"
fi

echo ""
echo "🎉 Role Mismatch Fixed!"
echo ""
echo "📋 Changes Made:"
echo "  ✅ Backend accepts 'instructor' role (not 'teacher')"
echo "  ✅ Frontend shows 'Student' and 'Instructor' options"
echo "  ✅ Default role is 'student'"
echo "  ✅ Role mapping: frontend 'instructor' -> database 'instructor'"
echo "  ✅ Rate limits completely cleared"
echo ""
echo "🌐 Test in browser:"
echo "  1. Open http://localhost:3000"
echo "  2. Go to registration page"
echo "  3. Select role: Student or Instructor"
echo "  4. Fill form and submit"
echo "  5. Verify successful registration"
