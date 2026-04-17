#!/bin/bash

echo "=== Check Backend Status ==="

# 1. Check container status
echo "1. Checking container status..."
docker compose ps

# 2. Check backend container logs
echo "2. Checking backend container logs..."
docker logs eduai-backend --tail 30

# 3. Check if backend container is running
echo "3. Checking if backend container is running..."
docker ps | grep eduai-backend

# 4. Check port mapping
echo "4. Checking port mapping..."
docker port eduai-backend

# 5. Check what's listening on port 4200
echo "5. Checking what's listening on port 4200..."
netstat -tlnp | grep :4200 || echo "Nothing listening on port 4200"

# 6. Test backend connection inside container
echo "6. Testing backend connection inside container..."
docker exec eduai-backend curl -I http://localhost:5000/health 2>/dev/null || echo "Internal health check failed"

echo "=== Status Check Complete ==="
