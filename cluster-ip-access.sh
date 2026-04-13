#!/bin/bash

# =============================================================================
# Cluster IP Direct Access Script
# Bypasses port forwarding issues with direct cluster IP access
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

# Get Minikube IP
MINIKUBE_IP=$(minikube ip)

echo "==============================================="
echo "  CLUSTER IP DIRECT ACCESS"
echo "==============================================="
echo ""
echo "Minikube IP: $MINIKUBE_IP"
echo ""

# Test all services with cluster IP
log "Testing Frontend..."
if curl -s -I http://$MINIKUBE_IP:30320 | grep -q "200 OK"; then
    success "Frontend accessible: http://$MINIKUBE_IP:30320"
else
    error "Frontend not accessible"
fi

log "Testing Backend API..."
if curl -s http://$MINIKUBE_IP:30420/api/v1/health | grep -q "healthy"; then
    success "Backend API healthy: http://$MINIKUBE_IP:30420"
else
    error "Backend API not healthy"
fi

# Get service IPs
FRONTEND_SVC_IP=$(kubectl get svc frontend -n eduai -o jsonpath='{.spec.clusterIP}')
BACKEND_SVC_IP=$(kubectl get svc backend -n eduai -o jsonpath='{.spec.clusterIP}')
GRAFANA_SVC_IP=$(kubectl get svc kube-prometheus-grafana -n monitoring -o jsonpath='{.spec.clusterIP}')
PROMETHEUS_SVC_IP=$(kubectl get svc kube-prometheus-kube-prome-alertmanager -n monitoring -o jsonpath='{.spec.clusterIP}')
ARGOCD_SVC_IP=$(kubectl get svc argocd-server -n eduai-argocd -o jsonpath='{.spec.clusterIP}')

echo ""
echo "==============================================="
echo "  CLUSTER IP ACCESS URLs"
echo "==============================================="
echo ""
echo "CORE PLATFORM:"
echo "  Frontend:     http://$MINIKUBE_IP:30320"
echo "  Backend:      http://$MINIKUBE_IP:30420"
echo "  AI Chat:      http://$MINIKUBE_IP:30420/ai-chat"
echo ""
echo "API ENDPOINTS:"
echo "  Health:       http://$MINIKUBE_IP:30420/api/v1/health"
echo "  Register:     http://$MINIKUBE_IP:30420/api/v1/auth/register"
echo "  Login:        http://$MINIKUBE_IP:30420/api/v1/auth/login"
echo "  AI Chat:      http://$MINIKUBE_IP:30420/api/v1/ai/chat"
echo ""
echo "SERVICE CLUSTER IPs:"
echo "  Frontend:     http://$FRONTEND_SVC_IP:3000"
echo "  Backend:      http://$BACKEND_SVC_IP:5000"
echo "  Grafana:      http://$GRAFANA_SVC_IP:3000"
echo "  Prometheus:   http://$PROMETHEUS_SVC_IP:9090"
echo "  ArgoCD:       http://$ARGOCD_SVC_IP:8080"
echo ""
echo "MONITORING NODEPORTS:"
echo "  Grafana:      http://$MINIKUBE_IP:30004 (admin/admin)"
echo "  Prometheus:   http://$MINIKUBE_IP:30930"
echo "  ArgoCD:       http://$MINIKUBE_IP:30880 (admin/admin123)"
echo ""
echo "==============================================="
echo ""
echo "RECOMMENDED ACCESS:"
echo "  Main Platform: http://$MINIKUBE_IP:30320"
echo "  API Testing:   http://$MINIKUBE_IP:30420/api/v1/health"
echo ""
echo "Your AI Smart Learning Platform is ready!"
echo "Open http://$MINIKUBE_IP:30320 in your browser."
echo ""
