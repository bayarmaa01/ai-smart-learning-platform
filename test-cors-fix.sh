#!/bin/bash

echo "=== CORS Fix Verification Script ==="
echo

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "ERROR: Docker is not running. Please start Docker Desktop first."
    exit 1
fi

echo "1. Restarting backend and nginx services..."
docker compose restart backend nginx

echo
echo "2. Waiting for services to be ready..."
sleep 10

echo
echo "3. Testing backend health endpoint..."
curl -i http://localhost:4000/api/v1/health

echo
echo "4. Testing CORS preflight request to login endpoint..."
curl -i -X OPTIONS http://localhost:4000/api/v1/auth/login \
  -H "Origin: http://localhost:3000" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: Content-Type, Authorization, Cache-Control, Pragma, Expires"

echo
echo "5. Testing actual login request (should work now)..."
curl -i -X POST http://localhost:4000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -H "Origin: http://localhost:3000" \
  -H "Cache-Control: no-store, no-cache, must-revalidate" \
  -H "Pragma: no-cache" \
  -H "Expires: 0" \
  -d '{"email": "test@example.com", "password": "testpass"}'

echo
echo "6. Checking nginx CORS configuration..."
docker exec eduai-nginx cat /etc/nginx/conf.d/default.conf | grep -A 10 "Access-Control-Allow-Headers"

echo
echo "=== CORS Fix Verification Complete ==="
echo "If you see 'Access-Control-Allow-Origin' headers with cache-control included, the fix is working!"
