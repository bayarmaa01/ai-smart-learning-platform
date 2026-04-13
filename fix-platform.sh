#!/bin/bash

# =============================================================================
# Complete Platform Fix Script
# Fixes all deployment issues: Grafana, ArgoCD, and monitoring
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

# Fix Grafana deployment
fix_grafana() {
    log "Fixing Grafana deployment..."
    
    # Delete problematic Grafana pod and deployment
    kubectl delete pod kube-prometheus-grafana-769976b8f4-68s4l -n monitoring --ignore-not-found=true
    kubectl delete deployment kube-prometheus-grafana -n monitoring --ignore-not-found=true
    
    # Wait for Helm to recreate
    sleep 10
    
    # Check if Grafana is working
    if kubectl get pods -l app.kubernetes.io/name=grafana -n monitoring | grep -q "Error"; then
        log "Grafana still in Error state, performing Helm upgrade..."
        helm upgrade kube-prometheus prometheus-community/kube-prometheus-stack \
            --namespace monitoring \
            --reuse-values \
            --force
    fi
    
    success "Grafana fix completed"
}

# Fix ArgoCD CRDs and deployment
fix_argocd() {
    log "Fixing ArgoCD deployment..."
    
    # Delete existing ArgoCD pods
    kubectl delete pods --all -n eduai-argocd --ignore-not-found=true
    
    # Install CRDs with working URLs
    log "Installing ArgoCD CRDs..."
    kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.9.6/manifests/crds.yaml || {
        log "Trying alternative CRD source..."
        kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.8.6/manifests/crds.yaml || {
            log "Installing CRDs via Helm..."
            helm repo add argo https://argoproj.github.io/argo-helm
            helm repo update
            helm install argo-crd argo/argo-cd --namespace eduai-argocd --set crds.install=true --set server.enabled=false || {
                warning "CRD installation failed, continuing..."
            }
        }
    }
    
    # Wait for CRDs to be established
    sleep 5
    
    # Redeploy ArgoCD
    log "Redeploying ArgoCD..."
    kubectl apply -f k8s/argocd-complete.yaml
    
    success "ArgoCD fix completed"
}

# Fix monitoring namespace issues
fix_monitoring() {
    log "Fixing monitoring configuration..."
    
    # Check monitoring pods
    kubectl get pods -n monitoring
    
    # Restart Prometheus if needed
    if ! kubectl get pods -l app.kubernetes.io/name=prometheus -n monitoring | grep -q "Running"; then
        log "Restarting Prometheus..."
        kubectl delete pod prometheus-kube-prometheus-kube-prome-prometheus-0 -n monitoring --ignore-not-found=true
    fi
    
    # Restart AlertManager if needed
    if ! kubectl get pods -l app.kubernetes.io/name=alertmanager -n monitoring | grep -q "Running"; then
        log "Restarting AlertManager..."
        kubectl delete pod alertmanager-kube-prometheus-kube-prome-alertmanager-0 -n monitoring --ignore-not-found=true
    fi
    
    success "Monitoring fix completed"
}

# Verify all services
verify_services() {
    log "Verifying all services..."
    
    echo ""
    echo "=== Core Platform Services ==="
    kubectl get pods -n eduai
    
    echo ""
    echo "=== Monitoring Services ==="
    kubectl get pods -n monitoring
    
    echo ""
    echo "=== ArgoCD Services ==="
    kubectl get pods -n eduai-argocd
    
    echo ""
    echo "=== Service Status ==="
    echo "Frontend NodePort:"
    kubectl get svc frontend-nodeport -n eduai -o wide
    echo "Backend NodePort:"
    kubectl get svc backend-nodeport -n eduai -o wide
    echo "Grafana Service:"
    kubectl get svc kube-prometheus-grafana -n monitoring -o wide || echo "Grafana service not found"
    echo "ArgoCD Service:"
    kubectl get svc argocd-server-nodeport -n eduai-argocd -o wide || echo "ArgoCD service not found"
    
    success "Service verification completed"
}

# Get access information
show_access_info() {
    echo ""
    echo "==============================================="
    echo "  PLATFORM ACCESS INFORMATION"
    echo "==============================================="
    echo ""
    
    # Get Minikube IP
    MINIKUBE_IP=$(minikube ip)
    
    echo "CORE PLATFORM:"
    echo "  Frontend:     http://$MINIKUBE_IP:30320"
    echo "  Backend:      http://$MINIKUBE_IP:30420"
    echo "  AI Chat:      http://$MINIKUBE_IP:30420/ai-chat"
    echo ""
    
    echo "MONITORING:"
    echo "  Grafana:      http://$MINIKUBE_IP:30004 (admin/admin)"
    echo "  Prometheus:   http://$MINIKUBE_IP:30930"
    echo ""
    
    echo "DEVOPS:"
    echo "  ArgoCD:       http://$MINIKUBE_IP:30880 (admin/admin123)"
    echo ""
    
    echo "AI SERVICES:"
    echo "  Ollama:       http://localhost:11434"
    echo ""
    
    echo "PORT FORWARDING ALTERNATIVE:"
    echo "  ./port-forward-setup.sh start"
    echo ""
    
    echo "==============================================="
}

# Main execution
main() {
    case "${1:-all}" in
        grafana)
            fix_grafana
            ;;
        argocd)
            fix_argocd
            ;;
        monitoring)
            fix_monitoring
            ;;
        verify)
            verify_services
            ;;
        access)
            show_access_info
            ;;
        all)
            fix_grafana
            fix_argocd
            fix_monitoring
            verify_services
            show_access_info
            ;;
        *)
            echo "Usage: $0 [grafana|argocd|monitoring|verify|access|all]"
            echo "  grafana   - Fix Grafana deployment issues"
            echo "  argocd    - Fix ArgoCD CRDs and deployment"
            echo "  monitoring - Fix monitoring services"
            echo "  verify    - Verify all services"
            echo "  access    - Show access information"
            echo "  all       - Fix everything (default)"
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"
