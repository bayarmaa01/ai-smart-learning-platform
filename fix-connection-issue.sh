#!/bin/bash

echo "=== Fix Connection Issue ==="

# 1. Stop frontend container
echo "1. Stopping frontend container..."
docker compose stop frontend

# 2. Remove frontend container completely
echo "2. Removing frontend container..."
docker compose rm -f frontend

# 3. Check if port 3200 is free
echo "3. Checking if port 3200 is free..."
sudo lsof -i :3200 || echo "Port 3200 is free"

# 4. Kill any process using port 3200
echo "4. Killing any process using port 3200..."
sudo fuser -k 3200/tcp 2>/dev/null || echo "No process to kill"

# 5. Wait a moment
echo "5. Waiting 3 seconds..."
sleep 3

# 6. Rebuild and start frontend
echo "6. Rebuilding and starting frontend..."
docker compose build --no-cache frontend
docker compose up -d frontend

# 7. Wait for container to start
echo "7. Waiting 10 seconds for container to start..."
sleep 10

# 8. Check container status
echo "8. Checking container status..."
docker compose ps frontend

# 9. Check logs
echo "9. Checking frontend logs..."
docker logs eduai-frontend --tail 10

# 10. Test connection
echo "10. Testing connection..."
curl -I http://localhost:3200

echo "=== Fix Complete ==="
echo ""
echo "If still not working, try these browser fixes:"
echo "1. Clear browser cache and cookies"
echo "2. Try incognito/private window"
echo "3. Try different browser (Chrome, Firefox, Edge)"
echo "4. Disable browser extensions temporarily"
echo "5. Check browser proxy settings"
echo "6. Try http://127.0.0.1:3200 instead of http://localhost:3200"
echo "7. Restart browser"
echo "8. Check Windows Defender Firewall settings"
echo "9. Try on different network (if using VPN, try without VPN)"
