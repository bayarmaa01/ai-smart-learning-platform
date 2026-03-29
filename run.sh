#!/bin/bash

set -euo pipefail

# =============================================================================
# ⚡ AI SMART LEARNING PLATFORM - FAST STARTUP
# =============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOMAIN="ailearn.duckdns.org"
TUNNEL_CONFIG_DIR="$HOME/.cloudflared"
FRONTEND_NODEPORT="30007"
BACKEND_NODEPORT="30008"

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
# STEP 3: ENSURE CLOUDFLARE TUNNEL IS RUNNING
# =============================================================================
ensure_tunnel_running() {
    log_info "Checking Cloudflare Tunnel status..."
    
    # Check if tunnel config exists
    if [ ! -f "$TUNNEL_CONFIG_DIR/config.yml" ]; then
        log_warning "Tunnel config not found. Please run ./devops.sh first."
        return 1
    fi
    
    # Check if tunnel is running
    if [ -f "$TUNNEL_CONFIG_DIR/tunnel.pid" ] && kill -0 $(cat "$TUNNEL_CONFIG_DIR/tunnel.pid") 2>/dev/null; then
        log_success "Cloudflare Tunnel is already running"
    else
        log_info "Starting Cloudflare Tunnel..."
        
        # Kill any existing tunnel processes
        pkill -f "cloudflared tunnel run" || true
        
        # Start tunnel in background
        nohup cloudflared tunnel run --config "$TUNNEL_CONFIG_DIR/config.yml" > "$TUNNEL_CONFIG_DIR/tunnel.log" 2>&1 &
        local tunnel_pid=$!
        
        # Wait for tunnel to start
        sleep 5
        
        # Check if tunnel is running
        if kill -0 $tunnel_pid 2>/dev/null; then
            log_success "Cloudflare Tunnel started (PID: $tunnel_pid)"
            echo $tunnel_pid > "$TUNNEL_CONFIG_DIR/tunnel.pid"
        else
            log_error "Failed to start Cloudflare Tunnel"
            tail -10 "$TUNNEL_CONFIG_DIR/tunnel.log"
            return 1
        fi
    fi
}

# =============================================================================
# STEP 4: HEALTH CHECK
# =============================================================================
health_check() {
    log_info "Performing health check..."
    
    local all_healthy=true
    
    # Check Minikube
    if ! minikube status -p eduai-cluster | grep -q "Running"; then
        log_error "Minikube is not running"
        all_healthy=false
    fi
    
    # Check pods
    local frontend_pods=$(kubectl get pods -n eduai -l app=frontend --no-headers | wc -l)
    local backend_pods=$(kubectl get pods -n eduai -l app=backend --no-headers | wc -l)
    
    if [ $frontend_pods -eq 0 ]; then
        log_error "Frontend pods are not running"
        all_healthy=false
    fi
    
    if [ $backend_pods -eq 0 ]; then
        log_error "Backend pods are not running"
        all_healthy=false
    fi
    
    # Check tunnel
    if [ ! -f "$TUNNEL_CONFIG_DIR/tunnel.pid" ] || ! kill -0 $(cat "$TUNNEL_CONFIG_DIR/tunnel.pid") 2>/dev/null; then
        log_error "Cloudflare Tunnel is not running"
        all_healthy=false
    fi
    
    if [ "$all_healthy" = true ]; then
        log_success "All components are healthy"
    else
        log_warning "Some components need attention"
    fi
}

# =============================================================================
# STEP 5: OUTPUT ACCESS INFORMATION
# =============================================================================
output_access_info() {
    log_info "Generating access information..."
    
    echo ""
    echo "=== 🚀 SYSTEM READY ==="
    echo ""
    
    echo "🌐 Domain:"
    echo "https://$DOMAIN"
    echo ""
    
    echo "Status:"
    local tunnel_status="❌ STOPPED"
    if [ -f "$TUNNEL_CONFIG_DIR/tunnel.pid" ] && kill -0 $(cat "$TUNNEL_CONFIG_DIR/tunnel.pid") 2>/dev/null; then
        tunnel_status="✅ RUNNING"
    fi
    
    local pods_status="❌ STOPPED"
    local frontend_pods=$(kubectl get pods -n eduai -l app=frontend --no-headers | wc -l)
    local backend_pods=$(kubectl get pods -n eduai -l app=backend --no-headers | wc -l)
    
    if [ $frontend_pods -gt 0 ] && [ $backend_pods -gt 0 ]; then
        pods_status="✅ RUNNING"
    fi
    
    echo "* Tunnel: $tunnel_status"
    echo "* Pods: $pods_status"
    echo "* Minikube: ✅ RUNNING"
    echo ""
    
    echo "📱 Local Access:"
    local minikube_ip=$(minikube ip -p eduai-cluster 2>/dev/null || echo "N/A")
    if [ "$minikube_ip" != "N/A" ]; then
        echo "Frontend: http://$minikube_ip:$FRONTEND_NODEPORT"
        echo "Backend:  http://$minikube_ip:$BACKEND_NODEPORT"
    fi
    echo ""
    
    echo "🔍 Quick Status:"
    echo "==============="
    kubectl get pods -n eduai
    echo ""
    
    echo "📋 Management Commands:"
    echo "======================"
    echo "Check tunnel logs: tail -f $TUNNEL_CONFIG_DIR/tunnel.log"
    echo "Restart tunnel: pkill -f cloudflared && ./run.sh"
    echo "Check pods: kubectl get pods -n eduai"
    echo "Stop system: pkill -f cloudflared && minikube stop -p eduai-cluster"
    echo ""
    
    log_success "System is ready for use!"
    log_info "Open https://$DOMAIN in your browser"
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
    ensure_tunnel_running
    health_check
    output_access_info
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo "⏱️  Startup completed in ${duration} seconds"
    echo ""
    echo "💡 Tips:"
    echo "   - Use ./run.sh again to refresh services"
    echo "   - Check logs with: tail -f $TUNNEL_CONFIG_DIR/tunnel.log"
    echo "   - Full redeploy with: ./devops.sh"
    echo ""
}

# Execute main function
main "$@"
