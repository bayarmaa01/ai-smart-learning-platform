#!/bin/bash

# Test the fixed registration system
echo "🧪 Testing Registration System Fixes..."

# Test 1: Backend health
echo "1. Testing backend health..."
curl -f http://localhost:5000/health 2>/dev/null && echo " ✅ Backend healthy" || echo " ❌ Backend unhealthy"

# Test 2: API health
echo "2. Testing API health..."
curl -f http://localhost:5000/api/v1/health 2>/dev/null && echo " ✅ API healthy" || echo " ❌ API unhealthy"

# Test 3: Valid registration (student)
echo "3. Testing student registration..."
TIMESTAMP=$(date +%s)
STUDENT_EMAIL="student_${TIMESTAMP}@example.com"
STUDENT_RESPONSE=$(curl -s -X POST http://localhost:5000/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d "{
    \"firstName\": \"John\",
    \"lastName\": \"Student\",
    \"email\": \"${STUDENT_EMAIL}\",
    \"password\": \"Student123!\",
    \"role\": \"student\"
  }")

if echo "$STUDENT_RESPONSE" | grep -q '"success":true'; then
    echo " ✅ Student registration successful"
else
    echo " ❌ Student registration failed"
    echo "$STUDENT_RESPONSE"
fi

# Wait a bit to avoid rate limiting
sleep 2

# Test 4: Valid registration (admin)
echo "4. Testing admin registration..."
TIMESTAMP2=$(date +%s)
ADMIN_EMAIL="admin_${TIMESTAMP2}@example.com"
ADMIN_RESPONSE=$(curl -s -X POST http://localhost:5000/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d "{
    \"firstName\": \"Jane\",
    \"lastName\": \"Admin\",
    \"email\": \"${ADMIN_EMAIL}\",
    \"password\": \"Admin123!\",
    \"role\": \"admin\"
  }")

if echo "$ADMIN_RESPONSE" | grep -q '"success":true'; then
    echo " ✅ Admin registration successful"
else
    echo " ❌ Admin registration failed"
    echo "$ADMIN_RESPONSE"
fi

# Wait a bit to avoid rate limiting
sleep 2

# Test 5: Duplicate email
echo "5. Testing duplicate email..."
DUPLICATE_RESPONSE=$(curl -s -X POST http://localhost:5000/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d "{
    \"firstName\": \"Duplicate\",
    \"lastName\": \"User\",
    \"email\": \"${STUDENT_EMAIL}\",
    \"password\": \"Duplicate123!\",
    \"role\": \"student\"
  }")

if echo "$DUPLICATE_RESPONSE" | grep -q '"code":"EMAIL_EXISTS"'; then
    echo " ✅ Duplicate email properly rejected"
else
    echo " ❌ Duplicate email not handled correctly"
    echo "$DUPLICATE_RESPONSE"
fi

# Wait a bit to avoid rate limiting
sleep 2

# Test 6: Invalid email
echo "6. Testing invalid email..."
INVALID_EMAIL_RESPONSE=$(curl -s -X POST http://localhost:5000/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{
    "firstName": "Invalid",
    "lastName": "Email",
    "email": "invalid-email",
    "password": "Invalid123!",
    "role": "student"
  }')

if echo "$INVALID_EMAIL_RESPONSE" | grep -q '"code":"INVALID_EMAIL"'; then
    echo " ✅ Invalid email properly rejected"
else
    echo " ❌ Invalid email not handled correctly"
    echo "$INVALID_EMAIL_RESPONSE"
fi

# Wait a bit to avoid rate limiting
sleep 2

# Test 7: Short password
echo "7. Testing short password..."
SHORT_PASSWORD_RESPONSE=$(curl -s -X POST http://localhost:5000/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{
    "firstName": "Short",
    "lastName": "Password",
    "email": "short@example.com",
    "password": "123",
    "role": "student"
  }')

if echo "$SHORT_PASSWORD_RESPONSE" | grep -q '"code":"PASSWORD_TOO_SHORT"'; then
    echo " ✅ Short password properly rejected"
else
    echo " ❌ Short password not handled correctly"
    echo "$SHORT_PASSWORD_RESPONSE"
fi

# Wait a bit to avoid rate limiting
sleep 2

# Test 8: Missing fields
echo "8. Testing missing fields..."
MISSING_FIELDS_RESPONSE=$(curl -s -X POST http://localhost:5000/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{
    "firstName": "Missing",
    "email": "missing@example.com",
    "password": "Missing123!",
    "role": "student"
  }')

if echo "$MISSING_FIELDS_RESPONSE" | grep -q '"code":"VALIDATION_ERROR"'; then
    echo " ✅ Missing fields properly rejected"
else
    echo " ❌ Missing fields not handled correctly"
    echo "$MISSING_FIELDS_RESPONSE"
fi

echo ""
echo "🎉 Registration System Tests Complete!"
echo ""
echo "📊 Test Results Summary:"
echo "  - Student registration: ${STUDENT_EMAIL}"
echo "  - Admin registration: ${ADMIN_EMAIL}"
echo ""
echo "🌐 Test in browser:"
echo "  1. Open http://localhost:3000"
echo "  2. Go to registration page"
echo "  3. Test with different emails and roles"
echo "  4. Verify smooth UI without grid borders"
echo ""
echo "📋 Expected results:"
echo "  - New users can register with any valid email"
echo "  - Role selection works (student/admin)"
echo "  - UI has no debug borders or grid lines"
echo "  - Proper validation and error responses"
echo ""
echo "⚠️  If you see rate limiting errors:"
echo "  Run: ./clear-rate-limit.sh"
