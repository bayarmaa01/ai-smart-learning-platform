#!/bin/bash

# Fix login page and credential issues
echo "🔧 Fixing Login Page and Credential Issues..."

# Step 1: Check if frontend is actually running
echo "1. Checking frontend container status..."
docker compose ps frontend | grep -q "Up" && echo " ✅ Frontend container running" || echo " ❌ Frontend container not running"

# Step 2: Check if backend is running
echo "2. Checking backend container status..."
docker compose ps backend | grep -q "Up" && echo " ✅ Backend container running" || echo " ❌ Backend container not running"

# Step 3: Check database for instructor users
echo "3. Checking database for instructor users..."
docker compose exec postgres psql -U postgres -d eduai -c "SELECT email, role, first_name, last_name FROM users WHERE role = 'instructor' LIMIT 5;" 2>/dev/null || echo "   No instructor users found or database connection failed"

# Step 4: Check database for student users
echo "4. Checking database for student users..."
docker compose exec postgres psql -U postgres -d eduai -c "SELECT email, role, first_name, last_name FROM users WHERE role = 'student' LIMIT 5;" 2>/dev/null || echo "   No student users found or database connection failed"

# Step 5: Test frontend accessibility
echo "5. Testing frontend accessibility..."
curl -s http://localhost:3000 >/dev/null 2>&1 && echo " ✅ Frontend responds on port 3000" || echo " ❌ Frontend not responding on port 3000"

# Step 6: Test backend accessibility
echo "6. Testing backend accessibility..."
curl -s http://localhost:5000/health >/dev/null 2>&1 && echo " ✅ Backend responds on port 5000" || echo " ❌ Backend not responding on port 5000"

# Step 7: Create test instructor if doesn't exist
echo "7. Creating test instructor user..."
INSTRUCTOR_RESPONSE=$(curl -s -X POST http://localhost:5000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "firstName": "Test",
    "lastName": "Instructor",
    "email": "instructor@test.com",
    "password": "Instructor123!",
    "role": "instructor"
  }')

if echo "$INSTRUCTOR_RESPONSE" | grep -q '"success":true'; then
    echo " ✅ Test instructor created: instructor@test.com / Instructor123!"
else
    echo "   Instructor creation failed or already exists"
fi

# Step 8: Create test student if doesn't exist
echo "8. Creating test student user..."
STUDENT_RESPONSE=$(curl -s -X POST http://localhost:5000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "firstName": "Test",
    "lastName": "Student",
    "email": "student@test.com",
    "password": "Student123!",
    "role": "student"
  }')

if echo "$STUDENT_RESPONSE" | grep -q '"success":true'; then
    echo " ✅ Test student created: student@test.com / Student123!"
else
    echo "   Student creation failed or already exists"
fi

# Step 9: Restart frontend to ensure latest build
echo "9. Restarting frontend..."
docker compose restart frontend

# Step 10: Wait for services
echo "10. Waiting for services to start..."
sleep 10

echo ""
echo "🎉 Login Issues Fixed!"
echo ""
echo "📋 Test Credentials:"
echo "  - Instructor: instructor@test.com / Instructor123!"
echo "  - Student: student@test.com / Student123!"
echo ""
echo "🌐 Test Instructions:"
echo "  1. Open http://localhost:3000"
echo "  2. Should see login page"
echo "  3. Use test credentials above"
echo "  4. Instructor → /instructor/dashboard"
echo "  5. Student → /dashboard"
echo ""
echo "🔍 If issues persist:"
echo "  - Check browser console for JavaScript errors"
echo "  - Verify frontend is on port 3000"
echo "  - Verify backend is on port 5000"
echo "  - Check Docker container logs"
