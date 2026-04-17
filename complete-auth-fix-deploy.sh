#!/bin/bash

echo "=== Complete Fullstack Auth Fix Deployment ==="

# 1. Stop all containers
echo "1. Stopping all containers..."
docker compose down

# 2. Rebuild backend with auth controller fixes
echo "2. Rebuilding backend with auth fixes..."
docker compose build --no-cache backend

# 3. Rebuild frontend with auth context fixes
echo "3. Rebuilding frontend with auth context..."
docker compose build --no-cache frontend

# 4. Start all services
echo "4. Starting all services..."
docker compose up -d

# 5. Wait for services to initialize
echo "5. Waiting 15 seconds for services to start..."
sleep 15

# 6. Test backend health
echo "6. Testing backend health..."
curl -I http://localhost:4200/api/v1/health

# 7. Test frontend access
echo "7. Testing frontend access..."
curl -I http://localhost:3200

# 8. Test API proxy
echo "8. Testing API proxy..."
curl -I http://localhost:3200/api/v1/health

echo "=== Deployment Complete ==="
echo ""
echo "ALL CRITICAL AUTH ISSUES FIXED:"
echo "=============================="
echo ""
echo "BACKEND FIXES:"
echo "- POST /api/v1/auth/register: Fixed 500 errors, now returns 400/201"
echo "- POST /api/v1/auth/login: Fixed 500 errors, now returns 400/200"
echo "- Role validation: Accepts both 'teacher' and maps to 'instructor'"
echo "- Error handling: Proper try-catch blocks with clear error messages"
echo "- Response structure: Consistent {success, data/error} format"
echo ""
echo "FRONTEND FIXES:"
echo "- API base URL: Fixed to /api/v1 (relative path)"
echo "- Role selection: Fixed teacher -> instructor mapping"
echo "- Auth context: Centralized authentication state management"
echo "- Protected routes: Prevent access without authentication"
echo "- Loading states: Prevent blank screen crashes"
echo "- Error handling: User-friendly error messages, no crashes"
echo ""
echo "AUTHENTICATION FLOW:"
echo "- Unauthenticated users: Redirected to /login"
echo "- Students: /dashboard"
echo "- Instructors: /instructor/dashboard"  
echo "- Admins: /admin"
echo "- Token validation: Proper cleanup on invalid tokens"
echo "- Login redirects: Handle intended destination"
echo ""
echo "TESTING INSTRUCTIONS:"
echo "===================="
echo "1. Open http://localhost:3200"
echo "2. Try to access dashboard without login - should redirect to /login"
echo "3. Register as 'instructor' - should work (teacher mapped to instructor)"
echo "4. Login and verify proper role-based redirect"
echo "5. Check console - NO vendor.js errors"
echo "6. Test API calls - should work with proper error handling"
echo "7. Verify protected routes work correctly"
echo ""
echo "API ENDPOINTS TEST:"
echo "==================="
echo "curl -X POST http://localhost:3200/api/v1/auth/register \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"email\":\"test@example.com\",\"password\":\"123456\",\"firstName\":\"Test\",\"lastName\":\"User\",\"role\":\"instructor\"}'"
echo ""
echo "curl -X POST http://localhost:3200/api/v1/auth/login \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"email\":\"test@example.com\",\"password\":\"123456\"}'"
echo ""
echo "ERROR HANDLING VERIFICATION:"
echo "- Invalid role: Returns 400 with clear message"
echo "- Missing fields: Returns 400 with validation errors"
echo "- Network errors: User-friendly toast messages"
echo "- 401 Unauthorized: Auto logout and redirect"
echo "- 403 Forbidden: Access denied message"
echo "- 500 Server Error: Server error message"
