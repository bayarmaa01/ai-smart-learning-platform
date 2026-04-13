#!/bin/bash

# =============================================================================
# Simple Port Forwarding Script
# Forwards all services to localhost access
# =============================================================================

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
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

# Backend (localhost:4200 -> NodePort 30420)  
kubectl port-forward -n eduai svc/backend-nodeport 4200:5000 &
BACKEND_PID=$!
log "Backend: http://localhost:4200 (NodePort: $MINIKUBE_IP:30420)"

# AI Chat (localhost:5200 -> NodePort 30420)
kubectl port-forward -n eduai svc/backend-nodeport 5200:5000 &
AI_PID=$!
log "AI Chat: http://localhost:5200 (NodePort: $MINIKUBE_IP:30420)"

# Grafana (localhost:3004 -> NodePort 30004)
kubectl port-forward -n monitoring svc/kube-prometheus-grafana 3004:3000 &
GRAFANA_PID=$!
log "Grafana: http://localhost:3004 (NodePort: $MINIKUBE_IP:30004)"

# Prometheus (localhost:9093 -> NodePort 30930)
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-kube-prome-prometheus 9093:9090 &
PROMETHEUS_PID=$!
log "Prometheus: http://localhost:9093 (NodePort: $MINIKUBE_IP:30930)"

# ArgoCD (localhost:18080 -> NodePort 30880)
kubectl port-forward -n eduai-argocd svc/argocd-server-nodeport 18080:8080 &
ARGOCD_PID=$!
log "ArgoCD: http://localhost:18080 (NodePort: $MINIKUBE_IP:30880)"

# Wait for port forwards to establish
sleep 5

# Show access info
echo ""
echo "==============================================="
echo "  PORT FORWARDING ACTIVE"
echo "==============================================="
echo ""
echo "📱 CORE PLATFORM:"
echo "  Frontend:     http://localhost:3200"
echo "  Backend:      http://localhost:4200"
echo "  AI Chat:      http://localhost:5200/ai-chat"
echo ""
echo "📊 MONITORING:"
echo "  Grafana:      http://localhost:3004 (admin/admin)"
echo "  Prometheus:   http://localhost:9093"
echo ""
echo "🔧 DEVOPS:"
echo "  ArgoCD:       http://localhost:18080 (admin/admin123)"
echo ""
echo "🌐 ALTERNATIVE ACCESS:"
echo "  Frontend:     http://$MINIKUBE_IP:30320"
echo "  Backend:      http://$MINIKUBE_IP:30420"
echo "  Grafana:      http://$MINIKUBE_IP:30004 (admin/admin)"
echo ""
echo "Press Ctrl+C to stop all port forwarding"
echo "==============================================="

# Wait for user to stop
trap 'echo ""; log "Stopping port forwarding..."; pkill -f "kubectl port-forward"; exit' INT

# Keep script running
wait
