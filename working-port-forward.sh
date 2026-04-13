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

# Frontend (localhost:3200 -> NodePort 30320)
kubectl port-forward -n eduai svc/frontend-nodeport 3200:3000 &
FRONTEND_PID=$!
log "Frontend: http://localhost:3200 (NodePort: $MINIKUBE_IP:30320)"

# Backend (localhost:5000 -> NodePort 30420)  
kubectl port-forward -n eduai svc/backend-nodeport 5000:5000 &
BACKEND_PID=$!
log "Backend: http://localhost:5000 (NodePort: $MINIKUBE_IP:30420)"

# AI Chat (localhost:5200 -> NodePort 30420)
kubectl port-forward -n eduai svc/backend-nodeport 5200:5000 &
AI_PID=$!
log "AI Chat: http://localhost:5200 (NodePort: $MINIKUBE_IP:30420)"

# Check if Grafana exists and forward
if kubectl get svc -n monitoring | grep -q grafana; then
    GRAFANA_SVC=$(kubectl get svc -n monitoring | grep grafana | awk '{print $1}')
    kubectl port-forward -n monitoring svc/$GRAFANA_SVC 3004:3000 &
    GRAFANA_PID=$!
    log "Grafana: http://localhost:3004 (NodePort: $MINIKUBE_IP:30004)"
else
    log "Grafana: Not available - recreating..."
    helm upgrade kube-prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --reuse-values
    sleep 10
    if kubectl get svc -n monitoring | grep -q grafana; then
        GRAFANA_SVC=$(kubectl get svc -n monitoring | grep grafana | awk '{print $1}')
        kubectl port-forward -n monitoring svc/$GRAFANA_SVC 3004:3000 &
        GRAFANA_PID=$!
        log "Grafana: http://localhost:3004 (NodePort: $MINIKUBE_IP:30004)"
    fi
fi

# Prometheus (localhost:9093)
PROMETHEUS_SVC=$(kubectl get svc -n monitoring | grep prometheus | head -1 | awk '{print $1}')
if [ -n "$PROMETHEUS_SVC" ]; then
    kubectl port-forward -n monitoring svc/$PROMETHEUS_SVC 9093:9090 &
    PROMETHEUS_PID=$!
    log "Prometheus: http://localhost:9093 (NodePort: $MINIKUBE_IP:30930)"
fi

# ArgoCD (localhost:18080)
if kubectl get svc -n eduai-argocd | grep -q argocd-server; then
    kubectl port-forward -n eduai-argocd svc/argocd-server 18080:8080 &
    ARGOCD_PID=$!
    log "ArgoCD: http://localhost:18080 (NodePort: $MINIKUBE_IP:30880)"
fi

# Wait for port forwards to establish
sleep 5

# Test connections
log "Testing connections..."
if curl -s http://localhost:3200 >/dev/null; then
    success "Frontend accessible"
else
    error "Frontend not accessible"
fi

if curl -s http://localhost:5000/api/v1/health >/dev/null; then
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
echo "  Backend:      http://localhost:5000"
echo "  AI Chat:      http://localhost:5200/ai-chat"
echo ""
echo "API Testing:"
echo "  Health:       http://localhost:5000/api/v1/health"
echo "  Login:        http://localhost:5000/api/v1/auth/login"
echo "  Register:     http://localhost:5000/api/v1/auth/register"
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
