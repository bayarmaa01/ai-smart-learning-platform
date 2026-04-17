#!/bin/bash

echo "=== Fix Nginx Proxy Configuration ==="

# 1. Stop frontend container
echo "1. Stopping frontend container..."
docker compose stop frontend

# 2. Remove frontend container
echo "2. Removing frontend container..."
docker compose rm -f frontend

# 3. Rebuild frontend with fixed nginx config
echo "3. Rebuilding frontend with fixed nginx config..."
docker compose build --no-cache frontend

# 4. Start frontend
echo "4. Starting frontend..."
docker compose up -d frontend

# 5. Wait for frontend to start
echo "5. Waiting 15 seconds for frontend to start..."
sleep 15

# 6. Test frontend access
echo "6. Testing frontend access..."
curl -I http://localhost:3200/ 2>/dev/null | head -3

echo ""

# 7. Test API proxy
echo "7. Testing API proxy..."
curl -I http://localhost:3200/api/v1/health 2>/dev/null | head -3

echo ""

# 8. Test auth endpoint through proxy
echo "8. Testing auth endpoint through proxy..."
curl -X POST http://localhost:3200/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"123456","firstName":"Test","lastName":"User","role":"student"}' \
  -w "\nHTTP Status: %{http_code}\n" \
  2>/dev/null

echo ""
echo "=== Nginx Proxy Fix Complete ==="
echo ""
echo "FIXES APPLIED:"
echo "- Added CORS preflight request handling"
echo "- Fixed Access-Control headers for OPTIONS requests"
echo "- Proper handling of cross-origin requests"
echo "- Maintained existing proxy configuration"
echo ""
echo "EXPECTED RESULTS:"
echo "- Frontend: http://localhost:3200 accessible"
echo "- API Proxy: http://localhost:3200/api/v1/health working"
echo "- Auth endpoints: No more 500 errors through proxy"
echo "- CORS: Proper handling of preflight requests"
