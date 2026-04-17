#!/bin/bash

echo "=== Restart Backend Service ==="

# 1. Stop backend
echo "1. Stopping backend..."
docker compose stop backend

# 2. Remove backend container
echo "2. Removing backend container..."
docker compose rm -f backend

# 3. Check backend logs before restart
echo "3. Getting backend logs..."
docker logs eduai-backend --tail 20 2>/dev/null || echo "No previous logs found"

# 4. Start backend
echo "4. Starting backend..."
docker compose up -d backend

# 5. Wait for startup
echo "5. Waiting 20 seconds for backend to start..."
sleep 20

# 6. Check container status
echo "6. Checking container status..."
docker compose ps backend

# 7. Check logs
echo "7. Checking startup logs..."
docker logs eduai-backend --tail 30

# 8. Test connection
echo "8. Testing connection..."
curl -I http://localhost:4200/api/v1/health 2>/dev/null || echo "Backend still not accessible"

echo "=== Restart Complete ==="
