#!/bin/bash

echo "=== Fix Logger Error in Database Query ==="

# 1. Stop backend container
echo "1. Stopping backend container..."
docker compose stop backend

# 2. Remove backend container
echo "2. Removing backend container..."
docker compose rm -f backend

# 3. Rebuild backend with fixed logger import
echo "3. Rebuilding backend with fixed logger import..."
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

# 7. Check backend logs for any errors
echo "7. Checking backend logs..."
docker logs eduai-backend --tail 10

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
echo "=== Logger Fix Complete ==="
echo ""
echo "FIXES APPLIED:"
echo "- Fixed logger import in database configuration"
echo "- Changed from 'const logger = require('../utils/logger')' to 'const { logger } = require('../utils/logger')'"
echo "- This matches the export structure from logger.js"
echo "- Should resolve 'logger.error is not a function' error"
echo ""
echo "EXPECTED RESULTS:"
echo "- Backend starts without logger errors"
echo "- Auth endpoints work without 500 errors"
echo "- Database queries execute successfully"
echo "- Registration and login work properly"
