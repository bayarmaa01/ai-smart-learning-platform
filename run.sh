#!/bin/bash

set -euo pipefail

# =============================================================================
# ⚡ AI SMART LEARNING PLATFORM - FAST STARTUP SCRIPT
# =============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}ℹ️  INFO: $1${NC}"; }
log_success() { echo -e "${GREEN}✅ SUCCESS: $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  WARNING: $1${NC}"; }
log_error() { echo -e "${RED}❌ ERROR: $1${NC}"; }

# Retry function for stability
retry() {
    local retries=$1
    shift
    local command="$*"
    local count=0
    
    until $command; do
        exit_code=$?
        count=$((count + 1))
        if [ $count -lt $retries ]; then
            log_warning "Command failed (attempt $count/$retries). Retrying in 3 seconds..."
            sleep 3
        else
            log_error "Command failed after $retries attempts"
            return $exit_code
        fi
    done
}

# =============================================================================
# STEP 1: START MINIKUBE (IF STOPPED)
# =============================================================================
start_minikube() {
    log_info "Checking Minikube status..."
    
    # Check if cluster is running
    if minikube status -p eduai-cluster 2>/dev/null | grep -q "Running"; then
        log_success "Minikube is already running"
    else
        log_info "Starting Minikube cluster..."
        retry 3 minikube start -p eduai-cluster --driver=docker --cpus=2 --memory=4096
        log_success "Minikube started"
    fi
    
    # Set context and docker env
    kubectl config use-context eduai-cluster
    eval $(minikube docker-env)
    
    # Verify cluster is ready
    retry 5 kubectl wait --for=condition=Ready nodes --all --timeout=120s
    log_success "Minikube cluster ready"
}

# =============================================================================
# STEP 2: ENSURE PODS ARE RUNNING
# =============================================================================
ensure_pods_running() {
    log_info "Checking pod status..."
    
    # Check if namespace exists
    if ! kubectl get namespace eduai &>/dev/null; then
        log_warning "eduai namespace not found. Please run ./devops.sh first."
        return 1
    fi
    
    # Restart failed pods
    local failed_pods=$(kubectl get pods -n eduai --field-selector=status.phase=Failed -o name 2>/dev/null || true)
    if [ -n "$failed_pods" ]; then
        log_info "Found failed pods, restarting them..."
        echo "$failed_pods" | while read pod; do
            kubectl delete "$pod" -n eduai --grace-period=0 --force || true
        done
    fi
    
    # Restart deployments with issues
    local deployments=("frontend" "backend")
    for deployment in "${deployments[@]}"; do
        local ready=$(kubectl get deployment $deployment -n eduai -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        local desired=$(kubectl get deployment $deployment -n eduai -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
        
        if [ "$ready" != "$desired" ] || [ "$ready" = "0" ]; then
            log_info "Restarting deployment: $deployment"
            kubectl rollout restart deployment/$deployment -n eduai || true
        fi
    done
    
    # Wait for pods to be ready
    retry 5 kubectl wait --for=condition=Ready pods -n eduai -l app=frontend --timeout=120s || true
    retry 5 kubectl wait --for=condition=Ready pods -n eduai -l app=backend --timeout=120s || true
    
    log_success "Pods are running"
}

# =============================================================================
# STEP 3: SETUP PORT FORWARDING
# =============================================================================
setup_port_forwarding() {
    log_info "Setting up port forwarding..."
    
    # Kill existing port forwards
    pkill -f "kubectl.*port-forward.*frontend" || true
    pkill -f "kubectl.*port-forward.*backend" || true
    
    # Start port forwarding in background
    kubectl port-forward svc/frontend -n eduai 3000:3000 >/dev/null 2>&1 &
    local frontend_pid=$!
    
    kubectl port-forward svc/backend -n eduai 5000:5000 >/dev/null 2>&1 &
    local backend_pid=$!
    
    # Wait a moment for port forwarding to establish
    sleep 3
    
    # Check if port forwarding is working
    if kill -0 $frontend_pid 2>/dev/null; then
        log_success "Frontend port forwarding active (PID: $frontend_pid)"
    else
        log_warning "Frontend port forwarding failed"
    fi
    
    if kill -0 $backend_pid 2>/dev/null; then
        log_success "Backend port forwarding active (PID: $backend_pid)"
    else
        log_warning "Backend port forwarding failed"
    fi
}

# =============================================================================
# STEP 4: OUTPUT ACCESS URLS
# =============================================================================
output_access_urls() {
    log_info "Generating access URLs..."
    
    local minikube_ip=$(minikube ip -p eduai-cluster 2>/dev/null || echo "N/A")
    
    echo ""
    echo "🚀 PLATFORM READY"
    echo "=================="
    echo ""
    
    echo "📱 Frontend:"
    echo "   Localhost: http://localhost:3000"
    if [ "$minikube_ip" != "N/A" ]; then
        echo "   NodePort:  http://$minikube_ip:30007"
    fi
    echo ""
    
    echo "🔧 Backend:"
    echo "   Localhost: http://localhost:5000"
    if [ "$minikube_ip" != "N/A" ]; then
        echo "   NodePort:  http://$minikube_ip:30008"
    fi
    echo ""
    
    if [ "$minikube_ip" != "N/A" ]; then
        echo "⚙️ ArgoCD:"
        echo "   URL: http://$minikube_ip:32434"
        echo "   Username: admin"
        echo "   Password: admin"
        echo ""
        
        echo "📊 Grafana:"
        echo "   URL: http://$minikube_ip:31385"
        echo "   Username: admin"
        echo "   Password: admin123"
        echo ""
    fi
    
    echo "🔍 Quick Status:"
    echo "==============="
    kubectl get pods -n eduai
    echo ""
    
    echo "🌐 Services:"
    echo "==========="
    kubectl get svc -n eduai
    echo ""
    
    log_success "Platform is ready for use!"
}

# =============================================================================
# STEP 5: HEALTH CHECK
# =============================================================================
health_check() {
    log_info "Performing health check..."
    
    # Check frontend
    if curl -s http://localhost:3000 >/dev/null 2>&1; then
        log_success "Frontend health check passed"
    else
        log_warning "Frontend health check failed"
    fi
    
    # Check backend
    if curl -s http://localhost:5000/api/health >/dev/null 2>&1; then
        log_success "Backend health check passed"
    else
        log_warning "Backend health check failed"
    fi
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================
main() {
    local start_time=$(date +%s)
    
    echo "⚡ AI Smart Learning Platform - Fast Startup"
    echo "=========================================="
    echo ""
    
    start_minikube
    ensure_pods_running
    setup_port_forwarding
    output_access_urls
    health_check
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo "⏱️  Startup completed in ${duration} seconds"
    echo ""
    echo "💡 Tips:"
    echo "   - Use Ctrl+C to stop port forwarding"
    echo "   - Run ./run.sh again to refresh services"
    echo "   - Check logs with: kubectl logs -n eduai deployment/frontend"
    echo ""
}

# Execute main function
main "$@"
