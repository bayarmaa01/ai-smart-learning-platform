#!/bin/bash

# =============================================================================
# Backend API Test Script
# Tests all API endpoints to verify functionality
# =============================================================================

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[TEST] $1${NC}"
}

success() {
    echo -e "${GREEN}[PASS] $1${NC}"
}

error() {
    echo -e "${RED}[FAIL] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARN] $1${NC}"
}

# Test endpoints
test_api() {
    local url=$1
    local method=${2:-GET}
    local data=${3:-""}
    local expected_status=${4:-200}
    
    log "Testing $method $url"
    
    if [ "$method" = "POST" ]; then
        response=$(curl -s -w "\n%{http_code}" -X POST \
            -H "Content-Type: application/json" \
            -d "$data" \
            "$url" 2>/dev/null || echo "000")
    else
        response=$(curl -s -w "\n%{http_code}" "$url" 2>/dev/null || echo "000")
    fi
    
    status=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n -1)
    
    if [ "$status" = "$expected_status" ]; then
        success "$method $url - Status $status"
        return 0
    else
        error "$method $url - Status $status (expected $expected_status)"
        echo "Response: $body"
        return 1
    fi
}

echo "==============================================="
echo "  BACKEND API TEST"
echo "==============================================="
echo ""

# Test different backend URLs
BACKEND_URLS=(
    "http://localhost:4200"
    "http://localhost:5000"
    "http://192.168.49.2:30420"
    "http://127.0.0.1:4200"
)

for url in "${BACKEND_URLS[@]}"; do
    log "Testing backend at $url"
    
    # Test health endpoint
    if test_api "$url/api/v1/health"; then
        echo ""
        success "Backend found at $url"
        echo ""
        
        # Test auth endpoints
        log "Testing authentication endpoints..."
        
        # Test register endpoint
        test_api "$url/api/v1/auth/register" "POST" \
            '{"email":"test@example.com","password":"test123456","name":"Test User"}' "201" || true
        
        # Test login endpoint  
        test_api "$url/api/v1/auth/login" "POST" \
            '{"email":"test@example.com","password":"test123456"}' "200" || true
        
        # Test AI endpoint
        test_api "$url/api/chat" "POST" \
            '{"message":"Hello"}' "200" || true
        
        echo ""
        success "All API tests completed for $url"
        echo ""
        echo "Working URLs:"
        echo "  Frontend: http://localhost:3200"
        echo "  Backend:  $url"
        echo "  API:      $url/api/v1/health"
        echo ""
        exit 0
    else
        warning "Backend not accessible at $url"
        echo ""
    fi
done

error "No working backend URL found"
echo ""
echo "Troubleshooting:"
echo "1. Check if backend pods are running: kubectl get pods -n eduai"
echo "2. Check backend service: kubectl get svc -n eduai"
echo "3. Check backend logs: kubectl logs -n eduai -l app=backend"
echo "4. Ensure port forwarding is running"
echo ""
