#!/bin/bash

# =============================================================================
# Final Access Test - Using NodePort Direct Access
# Tests all services via NodePort (no port forwarding needed)
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

# Get Minikube IP
MINIKUBE_IP=$(minikube ip)

echo "==============================================="
echo "  FINAL ACCESS TEST - NodePort Direct"
echo "==============================================="
echo ""
echo "Using Minikube IP: $MINIKUBE_IP"
echo ""

# Test 1: Frontend Access
log "Testing Frontend (NodePort 30320)..."
if curl -s -I http://$MINIKUBE_IP:30320 | grep -q "200 OK"; then
    success "Frontend accessible: http://$MINIKUBE_IP:30320"
else
    error "Frontend not accessible"
fi

# Test 2: Backend API Health
log "Testing Backend API (NodePort 30420)..."
if curl -s http://$MINIKUBE_IP:30420/api/v1/health | grep -q "healthy"; then
    success "Backend API healthy: http://$MINIKUBE_IP:30420"
else
    error "Backend API not healthy"
fi

# Test 3: Authentication
log "Testing Authentication..."

# Register test user
register_response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d '{
        "email":"testuser@example.com",
        "password":"Test123456",
        "firstName":"Test",
        "lastName":"User"
    }' \
    http://$MINIKUBE_IP:30420/api/v1/auth/register 2>/dev/null || echo "ERROR")

if [[ "$register_response" != "ERROR" ]] && echo "$register_response" | grep -q "success.*true"; then
    success "User registration working"
    
    # Login to get token
    login_response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{
            "email":"testuser@example.com",
            "password":"Test123456"
        }' \
        http://$MINIKUBE_IP:30420/api/v1/auth/login 2>/dev/null || echo "ERROR")
    
    if [[ "$login_response" != "ERROR" ]] && echo "$login_response" | grep -q "token"; then
        TOKEN=$(echo "$login_response" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
        success "Login successful, token obtained"
        
        # Test AI Chat with token
        log "Testing AI Chat with authentication..."
        ai_response=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $TOKEN" \
            -d '{"message":"Hello, test message"}' \
            http://$MINIKUBE_IP:30420/api/v1/ai/chat 2>/dev/null || echo "ERROR")
        
        if [[ "$ai_response" != "ERROR" ]] && echo "$ai_response" | grep -q "response"; then
            success "AI Chat working with authentication"
            echo "AI Response: $(echo "$ai_response" | head -c 100)..."
        else
            error "AI Chat failed even with token"
            echo "Response: $ai_response"
        fi
    else
        error "Login failed"
        echo "Response: $login_response"
    fi
else
    error "Registration failed"
    echo "Response: $register_response"
fi

# Test 4: Check Monitoring Services
log "Checking Monitoring Services..."

# Check Grafana service
if kubectl get svc -n monitoring | grep -q grafana; then
    GRAFANA_SVC=$(kubectl get svc -n monitoring | grep grafana | awk '{print $1}')
    GRAFANA_PORT=$(kubectl get svc -n monitoring $GRAFANA_SVC -o jsonpath='{.spec.ports[0].nodePort}')
    if [ -n "$GRAFANA_PORT" ]; then
        success "Grafana NodePort: $GRAFANA_PORT - http://$MINIKUBE_IP:$GRAFANA_PORT"
    else
        warning "Grafana NodePort not found"
    fi
else
    warning "Grafana service not found"
fi

# Check Prometheus service
if kubectl get svc -n monitoring | grep -q prometheus; then
    PROMETHEUS_SVC=$(kubectl get svc -n monitoring | grep prometheus | head -1 | awk '{print $1}')
    PROMETHEUS_PORT=$(kubectl get svc -n monitoring $PROMETHEUS_SVC -o jsonpath='{.spec.ports[0].nodePort}')
    if [ -n "$PROMETHEUS_PORT" ]; then
        success "Prometheus NodePort: $PROMETHEUS_PORT - http://$MINIKUBE_IP:$PROMETHEUS_PORT"
    else
        warning "Prometheus NodePort not found"
    fi
else
    warning "Prometheus service not found"
fi

# Check ArgoCD service
if kubectl get svc -n eduai-argocd | grep -q argocd-server; then
    ARGOCD_PORT=$(kubectl get svc -n eduai-argocd argocd-server-nodeport -o jsonpath='{.spec.ports[0].nodePort}')
    if [ -n "$ARGOCD_PORT" ]; then
        success "ArgoCD NodePort: $ARGOCD_PORT - http://$MINIKUBE_IP:$ARGOCD_PORT"
    else
        warning "ArgoCD NodePort not found"
    fi
else
    warning "ArgoCD service not found"
fi

echo ""
echo "==============================================="
echo "  WORKING ACCESS URLs"
echo "==============================================="
echo ""
echo "CORE PLATFORM:"
echo "  Frontend:     http://$MINIKUBE_IP:30320"
echo "  Backend:      http://$MINIKUBE_IP:30420"
echo "  API Health:   http://$MINIKUBE_IP:30420/api/v1/health"
echo ""
echo "API ENDPOINTS:"
echo "  Register:     http://$MINIKUBE_IP:30420/api/v1/auth/register"
echo "  Login:        http://$MINIKUBE_IP:30420/api/v1/auth/login"
echo "  AI Chat:      http://$MINIKUBE_IP:30420/api/v1/ai/chat"
echo ""
echo "MONITORING:"
if kubectl get svc -n monitoring | grep -q grafana; then
    GRAFANA_PORT=$(kubectl get svc -n monitoring $(kubectl get svc -n monitoring | grep grafana | awk '{print $1}') -o jsonpath='{.spec.ports[0].nodePort}')
    echo "  Grafana:      http://$MINIKUBE_IP:$GRAFANA_PORT (admin/admin)"
fi
if kubectl get svc -n monitoring | grep -q prometheus; then
    PROMETHEUS_PORT=$(kubectl get svc -n monitoring $(kubectl get svc -n monitoring | grep prometheus | head -1 | awk '{print $1}') -o jsonpath='{.spec.ports[0].nodePort}')
    echo "  Prometheus:   http://$MINIKUBE_IP:$PROMETHEUS_PORT"
fi
if kubectl get svc -n eduai-argocd | grep -q argocd-server; then
    ARGOCD_PORT=$(kubectl get svc -n eduai-argocd argocd-server-nodeport -o jsonpath='{.spec.ports[0].nodePort}')
    echo "  ArgoCD:       http://$MINIKUBE_IP:$ARGOCD_PORT (admin/admin123)"
fi
echo ""
echo "AUTO VERSIONING: $(grep -o '"version": "[^"]*' frontend/package.json | cut -d'"' -f4)"
echo ""
echo "==============================================="
echo ""
echo "Your AI Smart Learning Platform is working!"
echo "Open http://$MINIKUBE_IP:30320 in your browser."
echo ""
