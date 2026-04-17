#!/bin/bash

echo "=== Getting Backend Logs ==="

# 1. Check if Docker is running
echo "1. Checking Docker status..."
docker version > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Docker is not running. Please start Docker Desktop."
    exit 1
fi

# 2. Get backend container logs
echo "2. Getting backend container logs..."
docker logs eduai-backend --tail 50

# 3. Check container status
echo "3. Checking container status..."
docker compose ps

# 4. Test database connection
echo "4. Testing database connection..."
docker logs eduai-postgres --tail 10

echo "=== Logs Complete ==="
