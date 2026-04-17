#!/bin/bash

echo "=== Debug Auth Endpoints ==="

# 1. Test backend health
echo "1. Testing backend health..."
curl -v http://localhost:4200/api/v1/health 2>&1 | head -20

echo ""
echo "2. Testing register endpoint with valid data..."
curl -X POST http://localhost:4200/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "123456",
    "firstName": "Test",
    "lastName": "User",
    "role": "student"
  }' \
  -v 2>&1 | head -30

echo ""
echo "3. Testing register endpoint with instructor role..."
curl -X POST http://localhost:4200/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "instructor@example.com",
    "password": "123456",
    "firstName": "Test",
    "lastName": "Instructor",
    "role": "instructor"
  }' \
  -v 2>&1 | head -30

echo ""
echo "4. Testing login endpoint..."
curl -X POST http://localhost:4200/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "123456"
  }' \
  -v 2>&1 | head -30

echo ""
echo "5. Testing with missing fields (should return 400)..."
curl -X POST http://localhost:4200/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "123456"
  }' \
  -v 2>&1 | head -20

echo ""
echo "=== Debug Complete ==="
