#!/bin/bash

# =============================================================================
# Localhost Access Script
# Sets up port forwarding for localhost access to all services
# =============================================================================

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

# Stop existing forwards
pkill -f "kubectl port-forward" 2>/dev/null || true
sleep 2

echo "==============================================="
echo "  LOCALHOST ACCESS SETUP"
echo "==============================================="
echo ""

# Frontend (localhost:3200 -> frontend service 3000)
log "Setting up Frontend port forward (localhost:3200)..."
kubectl port-forward -n eduai svc/frontend 3200:3000 &
FRONTEND_PID=$!

# Backend (localhost:4200 -> backend service 5000)
log "Setting up Backend port forward (localhost:4200)..."
kubectl port-forward -n eduai svc/backend 4200:5000 &
BACKEND_PID=$!

# AI Chat (localhost:5200 -> backend service 5000)
log "Setting up AI Chat port forward (localhost:5200)..."
kubectl port-forward -n eduai svc/backend 5200:5000 &
AI_PID=$!

# Grafana (localhost:3004 -> grafana service 3000)
log "Setting up Grafana port forward (localhost:3004)..."
kubectl port-forward -n monitoring svc/kube-prometheus-grafana 3004:3000 &
GRAFANA_PID=$!

# Prometheus (localhost:9093 -> prometheus service 9090)
log "Setting up Prometheus port forward (localhost:9093)..."
kubectl port-forward -n monitoring svc/kube-prometheus-kube-prome-prometheus 9093:9090 &
PROMETHEUS_PID=$!

# ArgoCD (localhost:18080 -> argocd service 8080)
log "Setting up ArgoCD port forward (localhost:18080)..."
kubectl port-forward -n eduai-argocd svc/argocd-server 18080:8080 &
ARGOCD_PID=$!

# Wait for port forwards to establish
sleep 5

# Test connections
log "Testing connections..."
if curl -s http://localhost:3200 >/dev/null; then
    success "Frontend accessible"
else
    error "Frontend not accessible"
fi

if curl -s http://localhost:4200/api/v1/health >/dev/null; then
    success "Backend API accessible"
else
    error "Backend API not accessible"
fi

echo ""
echo "==============================================="
echo "  LOCALHOST ACCESS ACTIVE"
echo "==============================================="
echo ""
echo "WORKING LOCALHOST URLs:"
echo "  Frontend:     http://localhost:3200"
echo "  Backend:      http://localhost:4200"
echo "  AI Chat:      http://localhost:5200/ai-chat"
echo ""
echo "API ENDPOINTS:"
echo "  Health:       http://localhost:4200/api/v1/health"
echo "  Register:     http://localhost:4200/api/v1/auth/register"
echo "  Login:        http://localhost:4200/api/v1/auth/login"
echo "  AI Chat:      http://localhost:4200/api/v1/ai/chat"
echo ""
echo "MONITORING SERVICES:"
echo "  Grafana:      http://localhost:3004 (admin/admin)"
echo "  Prometheus:   http://localhost:9093"
echo ""
echo "DEVOPS SERVICES:"
echo "  ArgoCD:       http://localhost:18080 (admin/admin123)"
echo ""
echo "==============================================="
echo ""
echo "Your AI Smart Learning Platform is ready!"
echo "Open http://localhost:3200 in your browser."
echo ""
echo "Press Ctrl+C to stop all port forwarding"
echo ""

# Create cleanup function
cleanup() {
    echo ""
    log "Stopping port forwarding..."
    pkill -f "kubectl port-forward" 2>/dev/null || true
    exit 0
}

# Set up signal handlers
trap cleanup INT TERM

# Keep script running
wait
