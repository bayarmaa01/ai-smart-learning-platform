#!/bin/bash

echo "=== Deploy Auth Controller Fix ==="

# 1. Stop backend container
echo "1. Stopping backend container..."
docker compose stop backend

# 2. Remove backend container
echo "2. Removing backend container..."
docker compose rm -f backend

# 3. Rebuild backend with fixed auth controller
echo "3. Rebuilding backend with fixed auth controller..."
docker compose build --no-cache backend

# 4. Start backend
echo "4. Starting backend..."
docker compose up -d backend

# 5. Wait for backend to start
echo "5. Waiting 15 seconds for backend to start..."
sleep 15

# 6. Test backend health
echo "6. Testing backend health..."
curl -I http://localhost:4200/api/v1/health

# 7. Test register endpoint
echo "7. Testing register endpoint..."
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

# 8. Test login endpoint
echo "8. Testing login endpoint..."
curl -X POST http://localhost:4200/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "123456"
  }' \
  -w "\nHTTP Status: %{http_code}\n"

echo "=== Deploy Complete ==="
echo ""
echo "AUTH CONTROLLER FIXES:"
echo "- Simplified auth controller with proper error handling"
echo "- Removed complex dependencies that might cause 500 errors"
echo "- Added comprehensive logging for debugging"
echo "- Proper try-catch blocks around all database operations"
echo "- Fallback JWT secrets for missing environment variables"
echo ""
echo "EXPECTED RESULTS:"
echo "- Register: 201 Created on success"
echo "- Login: 200 OK on success"
echo "- Validation: 400 Bad Request on missing fields"
echo "- No more 500 Internal Server Errors"
