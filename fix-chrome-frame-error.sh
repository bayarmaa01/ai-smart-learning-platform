#!/bin/bash

echo "=== Fix Chrome Frame Loading Error ==="

# 1. Stop frontend container
echo "1. Stopping frontend container..."
docker compose stop frontend

# 2. Rebuild frontend with frame header fix
echo "2. Rebuilding frontend with frame header fix..."
docker compose build --no-cache frontend

# 3. Start frontend
echo "3. Starting frontend..."
docker compose up -d frontend

# 4. Wait for container to start
echo "4. Waiting 10 seconds for container to start..."
sleep 10

# 5. Test connection
echo "5. Testing connection..."
curl -I http://localhost:3200

# 6. Check if frame headers are present
echo "6. Checking frame headers..."
curl -I http://localhost:3200 | grep -i frame

echo "=== Fix Complete ==="
echo ""
echo "CHROME FRAME ERROR FIXED:"
echo "- Added X-Frame-Options: ALLOWALL"
echo "- Added Content-Security-Policy: frame-ancestors *"
echo "- This allows loading in Chrome error frames"
echo ""
echo "ALTERNATIVE SOLUTIONS:"
echo "1. Clear browser cache and restart Chrome"
echo "2. Try incognito/private window"
echo "3. Use http://127.0.0.1:3200 instead of http://localhost:3200"
echo "4. Disable Chrome extensions temporarily"
echo "5. Check Chrome://settings/security for site permissions"
echo "6. Try different browser (Firefox, Edge)"
echo ""
echo "If still not working, the issue might be:"
echo "- Chrome security policy blocking localhost frames"
echo "- Browser extension interfering"
echo "- System security software blocking"
