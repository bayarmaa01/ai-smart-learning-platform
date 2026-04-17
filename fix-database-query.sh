#!/bin/bash

echo "=== Fix Database Query Error ==="

# 1. Stop backend container
echo "1. Stopping backend container..."
docker compose stop backend

# 2. Remove backend container
echo "2. Removing backend container..."
docker compose rm -f backend

# 3. Rebuild backend with fixed database query
echo "3. Rebuilding backend with fixed database query..."
docker compose build --no-cache backend

# 4. Start backend
echo "4. Starting backend..."
docker compose up -d backend

# 5. Wait for backend to start
echo "5. Waiting 20 seconds for backend to start..."
sleep 20

# 6. Check backend status
echo "6. Checking backend status..."
docker compose ps backend

# 7. Check backend logs
echo "7. Checking backend logs..."
docker logs eduai-backend --tail 15

# 8. Test backend health
echo "8. Testing backend health..."
curl -I http://localhost:4200/api/v1/health

# 9. Test auth endpoint
echo "9. Testing auth endpoint..."
curl -X POST http://localhost:4200/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"123456","firstName":"Test","lastName":"User","role":"student"}' \
  -w "\nHTTP Status: %{http_code}\n"

echo ""
echo "=== Database Query Fix Complete ==="
echo ""
echo "FIXES APPLIED:"
echo "- Added pool validation in database query function"
echo "- Fixed 'Cannot read properties of undefined (reading query') error"
echo "- Ensures database connection is established before queries"
echo "- Maintains proper error handling and logging"
echo ""
echo "EXPECTED RESULTS:"
echo "- Backend starts without database errors"
echo "- Auth endpoints work without 500 errors"
echo "- Registration and login work properly"
echo "- Database queries execute successfully"
