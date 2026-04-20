#!/bin/bash

echo "=== Nginx CORS Fix Test Script ==="
echo

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "ERROR: Docker is not running. Please start Docker Desktop first."
    exit 1
fi

echo "1. Stopping all containers..."
docker compose down

echo
echo "2. Rebuilding and starting containers..."
docker compose up --build -d

echo
echo "3. Waiting for containers to start..."
sleep 15

echo
echo "4. Checking nginx container status..."
docker ps | grep eduai-nginx

echo
echo "5. Checking nginx logs for errors..."
docker logs eduai-nginx 2>&1 | head -20

echo
echo "6. Testing nginx health endpoint..."
curl -i http://localhost/health

echo
echo "7. Testing backend proxy (should work without CORS)..."
curl -i http://localhost/api/v1/health

echo
echo "8. Testing frontend access..."
curl -I http://localhost:3000/

echo
echo "9. Checking container network connectivity..."
docker exec eduai-nginx wget -qO- http://eduai-backend:5000/api/v1/health || echo "Backend connectivity failed"
docker exec eduai-nginx wget -qO- http://eduai-ai-service:8000/health || echo "AI service connectivity failed"

echo
echo "=== Test Summary ==="
echo "If nginx starts without errors and proxy tests work, CORS issue is fixed!"
echo "Frontend should now work at http://localhost:3000 with API calls via proxy."
