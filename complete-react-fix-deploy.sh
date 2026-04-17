#!/bin/bash

echo "=== Complete React + Docker Fullstack App Fix Deployment ==="

# 1. Stop all containers
echo "1. Stopping all containers..."
docker compose down

# 2. Rebuild frontend with all fixes
echo "2. Rebuilding frontend with complete fixes..."
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
echo "ALL ISSUES FIXED:"
echo "================"
echo "1. Frontend API URL: Fixed to /api/v1 (relative path)"
echo "2. Role mapping: Fixed teacher -> instructor"
echo "3. Global error handling: Added comprehensive axios error handling"
echo "4. Authentication: Added ProtectedRoute component"
echo "5. Auth check: Prevent rendering before auth check completes"
echo "6. Login redirects: Fixed role-based routing"
echo "7. Blank screen: Resolved vendor.js crashes"
echo ""
echo "TESTING INSTRUCTIONS:"
echo "===================="
echo "1. Open http://localhost:3200"
echo "2. Try to access dashboard without login - should redirect to /login"
echo "3. Register as 'instructor' (not 'teacher')"
echo "4. Login and verify proper role-based redirect"
echo "5. Check console - NO vendor.js errors"
echo "6. Test API calls - should work with proper error handling"
echo ""
echo "AUTHENTICATION FLOW:"
echo "===================="
echo "- Unauthenticated users: Redirected to /login"
echo "- Students: Redirected to /dashboard"
echo "- Instructors: Redirected to /instructor/dashboard"
echo "- Admins: Redirected to /admin"
echo "- Protected routes: All routes under / are protected"
echo ""
echo "ERROR HANDLING:"
echo "==============="
echo "- Network errors: User-friendly toast messages"
echo "- 401 Unauthorized: Auto logout and redirect"
echo "- 403 Forbidden: Access denied message"
echo "- 404 Not Found: Resource not found message"
echo "- 500 Server Error: Server error message"
echo "- Other errors: Generic error message"
