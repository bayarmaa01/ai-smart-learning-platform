#!/bin/bash

echo "=== Deploy React Crash Fix ==="

# 1. Stop frontend container
echo "1. Stopping frontend container..."
docker compose stop frontend

# 2. Rebuild frontend with correct configuration
echo "2. Rebuilding frontend..."
docker compose build --no-cache frontend

# 3. Start frontend
echo "3. Starting frontend..."
docker compose up -d frontend

# 4. Wait for container to start
echo "4. Waiting 10 seconds for initialization..."
sleep 10

# 5. Test frontend access
echo "5. Testing frontend access..."
curl -I http://localhost:3200

# 6. Test API proxy
echo "6. Testing API proxy..."
curl -I http://localhost:3200/api/v1/health

# 7. Test direct backend
echo "7. Testing direct backend..."
curl -I http://localhost:4200/api/v1/health

echo "=== Deployment Complete ==="
echo ""
echo "Expected results:"
echo "- Frontend: HTTP/1.1 200 OK"
echo "- API Proxy: HTTP/1.1 200 OK"
echo "- No React crash errors in browser console"
echo "- App loads properly without blank screen"
