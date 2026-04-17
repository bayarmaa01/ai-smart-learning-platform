#!/bin/bash

echo "=== Debugging React Production Errors ==="

# 1. Test if nginx proxy is working
echo "1. Testing nginx proxy..."
curl -I http://localhost:3200/api/v1/health

# 2. Test direct backend access
echo "2. Testing direct backend..."
curl -I http://localhost:4200/api/v1/health

# 3. Rebuild frontend with source maps enabled
echo "3. Rebuilding frontend with source maps..."
docker compose down frontend
docker compose build --build-arg VITE_BUILD_MODE=development frontend
docker compose up -d frontend

# 4. Wait for frontend to start
echo "4. Waiting for frontend to initialize..."
sleep 10

# 5. Test frontend access
echo "5. Testing frontend access..."
curl -I http://localhost:3200

# 6. Check container logs for errors
echo "6. Checking frontend container logs..."
docker logs eduai-frontend --tail 30

# 7. Test API communication from inside container
echo "7. Testing API from inside container..."
docker exec eduai-frontend curl -I http://localhost:3200/api/v1/health

echo "=== Debugging Complete ==="
echo ""
echo "If errors persist, check:"
echo "- Browser console for specific error messages"
echo "- Network tab for failed API requests"
echo "- Sources tab in browser dev tools"
echo "- Docker container logs with 'docker logs eduai-frontend'"
