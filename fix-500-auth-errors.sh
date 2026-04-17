#!/bin/bash

echo "=== Fix 500 Auth Errors ==="

# 1. Stop all containers
echo "1. Stopping all containers..."
docker compose down

# 2. Remove containers completely
echo "2. Removing containers..."
docker compose rm -f

# 3. Clean up any hanging processes
echo "3. Cleaning up processes..."
sudo fuser -k 3200/tcp 2>/dev/null || echo "Port 3200 clean"
sudo fuser -k 4200/tcp 2>/dev/null || echo "Port 4200 clean"

# 4. Rebuild backend with auth fixes
echo "4. Rebuilding backend with auth fixes..."
docker compose build --no-cache backend

# 5. Rebuild frontend with frame fixes
echo "5. Rebuilding frontend with frame fixes..."
docker compose build --no-cache frontend

# 6. Start all services
echo "6. Starting all services..."
docker compose up -d

# 7. Wait for services to initialize
echo "7. Waiting 20 seconds for services to start..."
sleep 20

# 8. Check container status
echo "8. Checking container status..."
docker compose ps

# 9. Test backend health
echo "9. Testing backend health..."
curl -I http://localhost:4200/api/v1/health

# 10. Test frontend access
echo "10. Testing frontend access..."
curl -I http://localhost:3200

# 11. Test auth endpoints
echo "11. Testing auth endpoints..."

echo "Testing register endpoint..."
curl -X POST http://localhost:3200/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "123456",
    "firstName": "Test",
    "lastName": "User",
    "role": "student"
  }' \
  -w "\nHTTP Status: %{http_code}\n"

echo "Testing login endpoint..."
curl -X POST http://localhost:3200/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "123456"
  }' \
  -w "\nHTTP Status: %{http_code}\n"

echo "=== Fix Complete ==="
echo ""
echo "If still getting 500 errors:"
echo "1. Check backend logs: docker logs eduai-backend --tail 50"
echo "2. Check database connection: docker logs eduai-postgres --tail 20"
echo "3. Check Redis connection: docker logs eduai-redis --tail 20"
echo "4. Verify environment variables in docker-compose.yml"
echo "5. Check if migrations ran successfully"
