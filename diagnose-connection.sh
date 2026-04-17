#!/bin/bash

echo "=== Diagnosing Connection Issues ==="

# 1. Check container status
echo "1. Checking container status..."
docker compose ps

# 2. Check nginx container logs
echo "2. Checking nginx container logs..."
docker logs eduai-frontend --tail 20

# 3. Check port mapping
echo "3. Checking port mapping..."
docker port eduai-frontend

# 4. Check if nginx is listening inside container
echo "4. Checking nginx process inside container..."
docker exec eduai-frontend ps aux | grep nginx

# 5. Test nginx config inside container
echo "5. Testing nginx config inside container..."
docker exec eduai-frontend nginx -t

# 6. Check if port 3200 is accessible
echo "6. Testing port 3200 accessibility..."
netstat -tlnp | grep :3200 || echo "Port 3200 not found in netstat"

# 7. Test with different methods
echo "7. Testing connection with different methods..."
echo "Testing curl to localhost:3200..."
curl -v http://localhost:3200/ 2>&1 | head -10

echo "Testing curl to 127.0.0.1:3200..."
curl -v http://127.0.0.1:3200/ 2>&1 | head -10

# 8. Check firewall status
echo "8. Checking firewall status..."
sudo ufw status || echo "UFW not available"

# 9. Check if any process is using port 3200
echo "9. Checking what's using port 3200..."
sudo lsof -i :3200 || echo "lsof not available or no process found"

echo "=== Diagnosis Complete ==="
