#!/bin/bash

echo "=== Test Auth Endpoints After Fix ==="

# Test 1: Register endpoint with valid data
echo "1. Testing register endpoint..."
curl -X POST http://localhost:4200/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "123456",
    "firstName": "Test",
    "lastName": "User",
    "role": "student"
  }' \
  -w "\nHTTP Status: %{http_code}\n"

echo ""

# Test 2: Login endpoint
echo "2. Testing login endpoint..."
curl -X POST http://localhost:4200/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "123456"
  }' \
  -w "\nHTTP Status: %{http_code}\n"

echo ""

# Test 3: Register with instructor role
echo "3. Testing register with instructor role..."
curl -X POST http://localhost:4200/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "instructor@example.com",
    "password": "123456",
    "firstName": "Instructor",
    "lastName": "Test",
    "role": "instructor"
  }' \
  -w "\nHTTP Status: %{http_code}\n"

echo ""

# Test 4: Register with teacher role (should map to instructor)
echo "4. Testing register with teacher role (should map to instructor)..."
curl -X POST http://localhost:4200/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "teacher@example.com",
    "password": "123456",
    "firstName": "Teacher",
    "lastName": "Test",
    "role": "teacher"
  }' \
  -w "\nHTTP Status: %{http_code}\n"

echo ""

# Test 5: Invalid data (should return 400)
echo "5. Testing with invalid data (should return 400)..."
curl -X POST http://localhost:4200/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "invalid-email",
    "password": "123"
  }' \
  -w "\nHTTP Status: %{http_code}\n"

echo ""
echo "=== Test Complete ==="
