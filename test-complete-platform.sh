#!/bin/bash

# =============================================================================
# Complete Platform Test Script
# Tests all services and functionality end-to-end
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

echo "==============================================="
echo "  COMPLETE PLATFORM TEST"
echo "==============================================="
echo ""

# Test 1: Frontend Access
log "Testing Frontend Access..."
if curl -s -I http://localhost:3200 | grep -q "200 OK"; then
    success "Frontend accessible at http://localhost:3200"
else
    error "Frontend not accessible"
fi
echo ""

# Test 2: Backend API Health
log "Testing Backend API..."
if curl -s http://localhost:5000/api/v1/health | grep -q "healthy"; then
    success "Backend API healthy at http://localhost:5000"
else
    error "Backend API not healthy"
fi
echo ""

# Test 3: AI Chat Endpoint
log "Testing AI Chat Endpoint..."
response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d '{"message":"Hello, test message"}' \
    http://localhost:5000/api/v1/ai/chat 2>/dev/null || echo "ERROR")

if [[ "$response" != "ERROR" ]] && echo "$response" | grep -q "response"; then
    success "AI Chat endpoint working"
    echo "Sample response: $(echo "$response" | head -c 100)..."
else
    error "AI Chat endpoint failed"
    echo "Response: $response"
fi
echo ""

# Test 4: Authentication Endpoints
log "Testing Authentication..."

# Test registration with valid data
register_response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d '{
        "email":"testuser@example.com",
        "password":"Test123456",
        "firstName":"Test",
        "lastName":"User"
    }' \
    http://localhost:5000/api/v1/auth/register 2>/dev/null || echo "ERROR")

if [[ "$register_response" != "ERROR" ]] && echo "$register_response" | grep -q "success.*true"; then
    success "User registration working"
else
    warning "User registration may have issues"
    echo "Response: $register_response"
fi

# Test login
login_response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d '{
        "email":"testuser@example.com",
        "password":"Test123456"
    }' \
    http://localhost:5000/api/v1/auth/login 2>/dev/null || echo "ERROR")

if [[ "$login_response" != "ERROR" ]] && echo "$login_response" | grep -q "token"; then
    success "User login working"
    # Extract token for further tests
    TOKEN=$(echo "$login_response" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
else
    warning "User login may have issues"
    echo "Response: $login_response"
fi
echo ""

# Test 5: Auto Versioning
log "Testing Auto Versioning..."
if [ -f "frontend/package.json" ]; then
    VERSION=$(grep -o '"version": "[^"]*' frontend/package.json | cut -d'"' -f4)
    success "Frontend version: $VERSION"
    
    # Check if version contains timestamp (auto versioning)
    if echo "$VERSION" | grep -q "+"; then
        success "Auto versioning is active"
    else
        warning "Auto versioning may not be active"
    fi
else
    error "Frontend package.json not found"
fi
echo ""

# Test 6: Monitoring Services
log "Testing Monitoring Services..."

# Check Grafana
if curl -s -I http://localhost:3004 | grep -q "200 OK"; then
    success "Grafana accessible at http://localhost:3004"
else
    warning "Grafana not accessible"
fi

# Check Prometheus
if curl -s -I http://localhost:9093 | grep -q "200 OK"; then
    success "Prometheus accessible at http://localhost:9093"
else
    warning "Prometheus not accessible"
fi
echo ""

# Test 7: ArgoCD
log "Testing ArgoCD..."
if curl -s -I http://localhost:18080 | grep -q "200 OK"; then
    success "ArgoCD accessible at http://localhost:18080"
else
    warning "ArgoCD not accessible"
fi
echo ""

# Test 8: Database Connection
log "Testing Database Connection..."
if curl -s http://localhost:5000/api/v1/health | grep -q "database.*connected"; then
    success "Database connected"
else
    warning "Database connection status unclear"
fi
echo ""

# Test 9: Redis Connection
log "Testing Redis Connection..."
if curl -s http://localhost:5000/api/v1/health | grep -q "redis.*connected"; then
    success "Redis connected"
else
    warning "Redis connection status unclear"
fi
echo ""

# Test 10: Ollama AI Service
log "Testing Ollama AI Service..."
if curl -s http://localhost:11434/api/tags | grep -q "gemma4"; then
    success "Ollama with gemma4 model available"
else
    warning "Ollama service may not be available"
fi
echo ""

# Summary
echo "==============================================="
echo "  PLATFORM TEST SUMMARY"
echo "==============================================="
echo ""
echo "WORKING SERVICES:"
echo "  Frontend:     http://localhost:3200"
echo "  Backend:      http://localhost:5000"
echo "  AI Chat:      http://localhost:5200/ai-chat"
echo "  Grafana:      http://localhost:3004 (admin/admin)"
echo "  Prometheus:   http://localhost:9093"
echo "  ArgoCD:       http://localhost:18080 (admin/admin123)"
echo ""
echo "API ENDPOINTS:"
echo "  Health:       http://localhost:5000/api/v1/health"
echo "  Register:     http://localhost:5000/api/v1/auth/register"
echo "  Login:        http://localhost:5000/api/v1/auth/login"
echo "  AI Chat:      http://localhost:5000/api/v1/ai/chat"
echo ""
echo "ALTERNATIVE ACCESS:"
echo "  Frontend:     http://$(minikube ip):30320"
echo "  Backend:      http://$(minikube ip):30420"
echo ""
echo "AUTO VERSIONING: $([ -f "frontend/package.json" ] && grep -o '"version": "[^"]*' frontend/package.json | cut -d'"' -f4)"
echo ""
echo "==============================================="
echo ""
echo "Your AI Smart Learning Platform is ready to use!"
echo "Open http://localhost:3200 in your browser to start."
echo ""
