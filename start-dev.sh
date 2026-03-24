#!/bin/bash

set -e

############################################
# LOGGING FUNCTIONS
############################################

log() {
    echo "[INFO] $(date '+%H:%M:%S') - $1"
}

success() {
    echo "[SUCCESS] $(date '+%H:%M:%S') - $1"
}

error() {
    echo "[ERROR] $(date '+%H:%M:%S') - $1"
    exit 1
}

############################################
# START MINIKUBE
############################################

start_minikube() {
    log "Checking Minikube status..."
    
    if minikube status -p eduai-cluster | grep -q "Running"; then
        success "Minikube is already running"
    else
        log "Starting Minikube cluster..."
        minikube start -p eduai-cluster
        success "Minikube started"
    fi
    
    # Set context
    kubectl config use-context eduai-cluster
    
    # Verify cluster
    if ! kubectl get nodes &> /dev/null; then
        error "Failed to connect to Minikube cluster"
    fi
}

############################################
# START CLOUDFLARE TUNNEL
############################################

start_cloudflare() {
    log "Checking Cloudflare Tunnel status..."
    
    if command -v systemctl &> /dev/null; then
        if systemctl is-active --quiet cloudflared 2>/dev/null; then
            success "Cloudflare Tunnel is running"
        else
            log "Starting Cloudflare Tunnel..."
            sudo systemctl start cloudflared || error "Failed to start Cloudflare Tunnel"
            success "Cloudflare Tunnel started"
        fi
    else
        log "systemctl not available, skipping Cloudflare Tunnel check"
    fi
}

############################################
# VERIFY KUBERNETES
############################################

verify_kubernetes() {
    log "Verifying Kubernetes connectivity..."
    
    if ! kubectl get nodes &> /dev/null; then
        error "Kubernetes cluster not accessible"
    fi
    
    success "Kubernetes is ready"
}

############################################
# AUTO-RECOVER PODS
############################################

recover_pods() {
    log "Checking pod status..."
    
    # Check for CrashLoopBackOff pods
    crashloop_pods=$(kubectl get pods -A --no-headers 2>/dev/null | grep -c "CrashLoopBackOff" || echo "0")
    
    if [ "$crashloop_pods" -gt 0 ]; then
        log "Found $crashloop_pods pods in CrashLoopBackOff, restarting deployments..."
        kubectl rollout restart deployment --all -A
        success "Pod recovery initiated"
    else
        success "All pods are healthy"
    fi
}

############################################
# GET NODEPORTS
############################################

get_nodeports() {
    log "Extracting service NodePorts..."
    
    # Get Minikube IP
    MINIKUBE_IP=$(minikube ip -p eduai-cluster)
    
    # Get Frontend NodePort (fixed 30007)
    FRONTEND_PORT=30007
    
    # Get ArgoCD NodePort
    ARGOCD_PORT=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30007")
    
    # Get Grafana NodePort
    GRAFANA_PORT=$(kubectl get svc monitoring-grafana -n monitoring -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30008")
    
    # Get Prometheus NodePort
    PROMETHEUS_PORT=$(kubectl get svc monitoring-kube-prometheus-prometheus -n monitoring -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30009")
    
    success "Service ports extracted"
}

############################################
# PRINT URLS
############################################

print_urls() {
    echo ""
    echo "----------------------------------"
    echo "🚀 PLATFORM:"
    echo "https://ailearn.duckdns.org"
    echo ""
    echo "🔧 INTERNAL SERVICES:"
    
    # Get Minikube IP
    MINIKUBE_IP=$(minikube ip -p eduai-cluster)
    
    # Get ArgoCD NodePort
    ARGOCD_PORT=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30007")
    
    # Get Grafana NodePort
    GRAFANA_PORT=$(kubectl get svc monitoring-grafana -n monitoring -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30008")
    
    # Get Prometheus NodePort
    PROMETHEUS_PORT=$(kubectl get svc monitoring-kube-prometheus-prometheus -n monitoring -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30009")
    
    echo "⚙️ ARGOCD:"
    echo "http://$MINIKUBE_IP:$ARGOCD_PORT"
    
    echo "📊 GRAFANA:"
    echo "http://$MINIKUBE_IP:$GRAFANA_PORT"
    echo "   (admin/admin123)"
    
    echo "📈 PROMETHEUS:"
    echo "http://$MINIKUBE_IP:$PROMETHEUS_PORT"
    echo "----------------------------------"
    echo ""
    echo "🔍 QUICK COMMANDS:"
    echo "kubectl get pods -A"
    echo "kubectl get svc -A"
    echo "minikube service list"
    echo "   ./access-services.sh  # For detailed access info"
    echo ""
    echo "🎯 PORT FORWARDING:"
    echo "kubectl port-forward svc/frontend -n eduai 3000:3000"
    echo "kubectl port-forward svc/backend -n eduai 5000:5000"
    echo ""
}

############################################
# MAIN EXECUTION
############################################

main() {
    echo "🚀 EDUAI Development Startup"
    echo "============================="
    
    start_minikube
    start_cloudflare
    verify_kubernetes
    recover_pods
    get_nodeports
    print_urls
    
    success "Development environment ready!"
}

# Execute main function
main "$@"
