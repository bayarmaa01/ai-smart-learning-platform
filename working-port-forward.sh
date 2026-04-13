#!/bin/bash

# =============================================================================
# Working Port Forwarding Script
# Fixed service names and proper error handling
# =============================================================================

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')] $1${NC}"
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

# Get Minikube IP
MINIKUBE_IP=$(minikube ip)

log "Starting port forwarding..."

# Frontend (localhost:3200 -> frontend service 3000)
kubectl port-forward -n eduai svc/frontend 3200:3000 &
FRONTEND_PID=$!
log "Frontend: http://localhost:3200 (NodePort: $MINIKUBE_IP:30320)"

# Backend (localhost:4200 -> backend service 5000)
kubectl port-forward -n eduai svc/backend 4200:5000 &
BACKEND_PID=$!
log "Backend: http://localhost:4200 (NodePort: $MINIKUBE_IP:30420)"

# AI Chat (localhost:5200 -> backend service 5000)
kubectl port-forward -n eduai svc/backend 5200:5000 &
AI_PID=$!
log "AI Chat: http://localhost:5200 (NodePort: $MINIKUBE_IP:30420)"

# Grafana (localhost:3004) - use standard service name
kubectl port-forward -n monitoring svc/kube-prometheus-grafana 3004:3000 &
GRAFANA_PID=$!
log "Grafana: http://localhost:3004 (admin/admin)"

# Prometheus (localhost:9093) - use correct service name
kubectl port-forward -n monitoring svc/kube-prometheus-prometheus 9093:9090 &
PROMETHEUS_PID=$!
log "Prometheus: http://localhost:9093"

# ArgoCD (localhost:18080) - use standard service name
kubectl port-forward -n eduai-argocd svc/argocd-server 18080:8080 &
ARGOCD_PID=$!
log "ArgoCD: http://localhost:18080 (admin/admin123)"

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

# Show access info
echo ""
echo "==============================================="
echo "  PORT FORWARDING ACTIVE"
echo "==============================================="
echo ""
echo "Working URLs:"
echo "  Frontend:     http://localhost:3200"
echo "  Backend:      http://localhost:4200"
echo "  AI Chat:      http://localhost:5200/ai-chat"
echo ""
echo "API Testing:"
echo "  Health:       http://localhost:4200/api/v1/health"
echo "  Login:        http://localhost:4200/api/v1/auth/login"
echo "  Register:     http://localhost:4200/api/v1/auth/register"
echo ""
echo "Monitoring:"
echo "  Grafana:      http://localhost:3004 (admin/admin)"
echo "  Prometheus:   http://localhost:9093"
echo ""
echo "Alternative Access:"
echo "  Frontend:     http://$MINIKUBE_IP:30320"
echo "  Backend:      http://$MINIKUBE_IP:30420"
echo ""
echo "Press Ctrl+C to stop all port forwarding"
echo "==============================================="

# Wait for user to stop
trap 'echo ""; log "Stopping port forwarding..."; pkill -f "kubectl port-forward"; exit' INT

# Keep script running
wait
