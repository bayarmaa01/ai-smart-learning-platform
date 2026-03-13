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
STUDENT_RESPONSE=$(curl -s -w "%{http_code}" -X POST http://localhost:5000/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{
    "firstName": "John",
    "lastName": "Student",
    "email": "student@example.com",
    "password": "Student123!",
    "role": "student"
  }')

STUDENT_STATUS=$(echo "$STUDENT_RESPONSE" | tail -c 3)
if [ "$STUDENT_STATUS" = "201" ]; then
    echo " ✅ Student registration successful (201)"
else
    echo " ❌ Student registration failed ($STUDENT_STATUS)"
    echo "$STUDENT_RESPONSE"
fi

# Test 4: Valid registration (admin)
echo "4. Testing admin registration..."
ADMIN_RESPONSE=$(curl -s -w "%{http_code}" -X POST http://localhost:5000/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{
    "firstName": "Jane",
    "lastName": "Admin",
    "email": "admin@example.com",
    "password": "Admin123!",
    "role": "admin"
  }')

ADMIN_STATUS=$(echo "$ADMIN_RESPONSE" | tail -c 3)
if [ "$ADMIN_STATUS" = "201" ]; then
    echo " ✅ Admin registration successful (201)"
else
    echo " ❌ Admin registration failed ($ADMIN_STATUS)"
    echo "$ADMIN_RESPONSE"
fi

# Test 5: Duplicate email
echo "5. Testing duplicate email..."
DUPLICATE_RESPONSE=$(curl -s -w "%{http_code}" -X POST http://localhost:5000/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{
    "firstName": "Duplicate",
    "lastName": "User",
    "email": "student@example.com",
    "password": "Duplicate123!",
    "role": "student"
  }')

DUPLICATE_STATUS=$(echo "$DUPLICATE_RESPONSE" | tail -c 3)
if [ "$DUPLICATE_STATUS" = "409" ]; then
    echo " ✅ Duplicate email properly rejected (409)"
else
    echo " ❌ Duplicate email not handled correctly ($DUPLICATE_STATUS)"
    echo "$DUPLICATE_RESPONSE"
fi

# Test 6: Invalid email
echo "6. Testing invalid email..."
INVALID_EMAIL_RESPONSE=$(curl -s -w "%{http_code}" -X POST http://localhost:5000/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{
    "firstName": "Invalid",
    "lastName": "Email",
    "email": "invalid-email",
    "password": "Invalid123!",
    "role": "student"
  }')

INVALID_EMAIL_STATUS=$(echo "$INVALID_EMAIL_RESPONSE" | tail -c 3)
if [ "$INVALID_EMAIL_STATUS" = "400" ]; then
    echo " ✅ Invalid email properly rejected (400)"
else
    echo " ❌ Invalid email not handled correctly ($INVALID_EMAIL_STATUS)"
fi

# Test 7: Short password
echo "7. Testing short password..."
SHORT_PASSWORD_RESPONSE=$(curl -s -w "%{http_code}" -X POST http://localhost:5000/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{
    "firstName": "Short",
    "lastName": "Password",
    "email": "short@example.com",
    "password": "123",
    "role": "student"
  }')

SHORT_PASSWORD_STATUS=$(echo "$SHORT_PASSWORD_RESPONSE" | tail -c 3)
if [ "$SHORT_PASSWORD_STATUS" = "400" ]; then
    echo " ✅ Short password properly rejected (400)"
else
    echo " ❌ Short password not handled correctly ($SHORT_PASSWORD_STATUS)"
fi

# Test 8: Missing fields
echo "8. Testing missing fields..."
MISSING_FIELDS_RESPONSE=$(curl -s -w "%{http_code}" -X POST http://localhost:5000/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{
    "firstName": "Missing",
    "email": "missing@example.com",
    "password": "Missing123!",
    "role": "student"
  }')

MISSING_FIELDS_STATUS=$(echo "$MISSING_FIELDS_RESPONSE" | tail -c 3)
if [ "$MISSING_FIELDS_STATUS" = "400" ]; then
    echo " ✅ Missing fields properly rejected (400)"
else
    echo " ❌ Missing fields not handled correctly ($MISSING_FIELDS_STATUS)"
fi

echo ""
echo "🎉 Registration System Tests Complete!"
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
