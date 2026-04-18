#!/bin/bash

# EduAI Platform - System Verification Script
# This script verifies that all fixes are working correctly

set -e

echo "🔍 EduAI Platform - System Verification Script"
echo "============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_test() {
    echo -e "${YELLOW}[TEST]${NC} $1"
}

# Test 1: Service Health Checks
print_status "Test 1: Checking Service Health"

services=("eduai-postgres:5432" "eduai-redis:6379" "eduai-ollama:11434" "eduai-backend:5000" "eduai-frontend:80" "eduai-nginx:80" "eduai-prometheus:9090" "eduai-grafana:3000")

for service_info in "${services[@]}"; do
    service_name=$(echo $service_info | cut -d: -f1)
    port=$(echo $service_info | cut -d: -f2)
    
    if docker ps --format "table {{.Names}}" | grep -q "$service_name"; then
        print_status "✅ $service_name is running"
        
        # Test port accessibility
        if nc -z localhost $port 2>/dev/null; then
            print_status "✅ Port $port is accessible"
        else
            print_warning "⚠️ Port $port might not be accessible from host"
        fi
    else
        print_error "❌ $service_name is not running"
    fi
done

echo ""

# Test 2: API Endpoints
print_status "Test 2: Testing API Endpoints"

# Test backend health
print_test "Testing backend health endpoint..."
if curl -s -f http://localhost:80/api/v1/health > /dev/null; then
    print_status "✅ Backend health endpoint working"
else
    print_error "❌ Backend health endpoint failed"
fi

# Test auth endpoints
print_test "Testing auth register endpoint..."
if curl -s -X POST http://localhost:80/api/v1/auth/register \
    -H "Content-Type: application/json" \
    -d '{"email":"test@example.com","password":"test123456","firstName":"Test","lastName":"User","role":"student"}' \
    | grep -q "success"; then
    print_status "✅ Auth register endpoint working"
else
    print_error "❌ Auth register endpoint failed"
fi

print_test "Testing auth login endpoint..."
if curl -s -X POST http://localhost:80/api/v1/auth/login \
    -H "Content-Type: application/json" \
    -d '{"email":"test@example.com","password":"test123456"}' \
    | grep -q "accessToken"; then
    print_status "✅ Auth login endpoint working"
else
    print_error "❌ Auth login endpoint failed"
fi

echo ""

# Test 3: Frontend Accessibility
print_status "Test 3: Testing Frontend Accessibility"

print_test "Testing frontend main page..."
if curl -s -f http://localhost:80/ > /dev/null; then
    print_status "✅ Frontend main page accessible"
else
    print_error "❌ Frontend main page not accessible"
fi

print_test "Testing frontend login page..."
if curl -s -f http://localhost:80/login > /dev/null; then
    print_status "✅ Frontend login page accessible"
else
    print_error "❌ Frontend login page not accessible"
fi

echo ""

# Test 4: Database Schema Verification
print_status "Test 4: Verifying Database Schema"

print_test "Checking database schema..."
docker exec eduai-postgres psql -U postgres -d eduai -c "
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'users' AND column_name IN ('role', 'tenant_id', 'email_verification_token', 'last_login_at')
ORDER BY column_name;" > /tmp/db_schema_check.txt

if grep -q "instructor" /tmp/db_schema_check.txt; then
    print_status "✅ Database schema updated correctly"
else
    print_error "❌ Database schema not updated properly"
fi

echo ""

# Test 5: Authentication Flow
print_status "Test 5: Testing Authentication Flow"

print_test "Creating test user and getting token..."
TOKEN=$(curl -s -X POST http://localhost:80/api/v1/auth/register \
    -H "Content-Type: application/json" \
    -d '{"email":"authtest@example.com","password":"test123456","firstName":"Auth","lastName":"Test","role":"instructor"}' \
    | jq -r '.data.accessToken')

if [ "$TOKEN" != "null" ] && [ "$TOKEN" != "" ]; then
    print_status "✅ User registration and token generation working"
    
    # Test protected endpoint
    print_test "Testing protected endpoint with token..."
    if curl -s -H "Authorization: Bearer $TOKEN" http://localhost:80/api/v1/auth/me \
        | grep -q "instructor"; then
        print_status "✅ Protected endpoint authentication working"
    else
        print_error "❌ Protected endpoint authentication failed"
    fi
else
    print_error "❌ Token generation failed"
fi

echo ""

# Test 6: Monitoring Services
print_status "Test 6: Testing Monitoring Services"

print_test "Testing Prometheus..."
if curl -s -f http://localhost:9090/-/healthy > /dev/null; then
    print_status "✅ Prometheus is healthy"
else
    print_error "❌ Prometheus is not healthy"
fi

print_test "Testing Grafana..."
if curl -s -f http://localhost:3001/api/health > /dev/null; then
    print_status "✅ Grafana is healthy"
else
    print_error "❌ Grafana is not healthy"
fi

echo ""

# Test 7: Role-based Access
print_status "Test 7: Testing Role-based Access"

print_test "Creating student user..."
STUDENT_TOKEN=$(curl -s -X POST http://localhost:80/api/v1/auth/register \
    -H "Content-Type: application/json" \
    -d '{"email":"student@example.com","password":"test123456","firstName":"Student","lastName":"User","role":"student"}' \
    | jq -r '.data.accessToken')

print_test "Creating instructor user..."
INSTRUCTOR_TOKEN=$(curl -s -X POST http://localhost:80/api/v1/auth/register \
    -H "Content-Type: application/json" \
    -d '{"email":"instructor@example.com","password":"test123456","firstName":"Instructor","lastName":"User","role":"instructor"}' \
    | jq -r '.data.accessToken')

if [ "$STUDENT_TOKEN" != "null" ] && [ "$INSTRUCTOR_TOKEN" != "null" ]; then
    print_status "✅ Role-based user creation working"
    
    # Test student token
    STUDENT_ROLE=$(curl -s -H "Authorization: Bearer $STUDENT_TOKEN" http://localhost:80/api/v1/auth/me | jq -r '.data.user.role')
    INSTRUCTOR_ROLE=$(curl -s -H "Authorization: Bearer $INSTRUCTOR_TOKEN" http://localhost:80/api/v1/auth/me | jq -r '.data.user.role')
    
    if [ "$STUDENT_ROLE" = "student" ] && [ "$INSTRUCTOR_ROLE" = "instructor" ]; then
        print_status "✅ Role assignment working correctly"
    else
        print_error "❌ Role assignment failed"
    fi
else
    print_error "❌ Role-based user creation failed"
fi

echo ""

# Summary
print_status "🎯 Verification Summary"
echo "============================="

echo "If all tests passed, your system is working correctly!"
echo ""
echo "Next steps:"
echo "1. Open http://localhost:80 in your browser"
echo "2. Register a new user or use demo accounts"
echo "3. Test the authentication flow"
echo "4. Verify dashboard access based on user role"
echo ""
echo "For debugging:"
echo "- Check logs: docker-compose logs -f [service-name]"
echo "- Restart services: docker-compose restart [service-name]"
echo "- View running containers: docker ps"

# Cleanup temp files
rm -f /tmp/db_schema_check.txt

print_status "✅ System verification completed!"
