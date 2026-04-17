#!/bin/bash

echo "=== FINAL React Crash Fix Deployment ==="

# 1. Stop all containers
echo "1. Stopping all containers..."
docker compose down

# 2. Rebuild frontend with fixed main.jsx
echo "2. Rebuilding frontend with fixed Redux/QueryClient setup..."
docker compose build --no-cache frontend

# 3. Start all services
echo "3. Starting all services..."
docker compose up -d

# 4. Wait for services to initialize
echo "4. Waiting 15 seconds for services to start..."
sleep 15

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
echo "EXPECTED RESULTS:"
echo "=================="
echo "Frontend: HTTP/1.1 200 OK"
echo "API Proxy: HTTP/1.1 200 OK"
echo "Backend: HTTP/1.1 200 OK"
echo ""
echo "BROWSER TEST:"
echo "============="
echo "1. Open http://localhost:3200"
echo "2. Check console - NO vendor-*.js errors"
echo "3. App should load without blank screen"
echo "4. All React components should render"
echo ""
echo "ROOT CAUSE FIXED:"
echo "================="
echo "- Removed Redux Provider from main.jsx"
echo "- App.jsx already had QueryClientProvider"
echo "- Fixed authService API URL fallback"
echo "- Resolved component initialization conflict"
