#!/bin/bash

set -euo pipefail

# =============================================================================
# ⚡ AI SMART LEARNING PLATFORM - FAST RUNTIME
# =============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
DOMAIN="ailearn.duckdns.org"
TUNNEL_CONFIG_DIR="$HOME/.cloudflared"
NAMESPACE="eduai"

# Logging
log_info() { echo -e "${BLUE}ℹ️  INFO: $1${NC}"; }
log_success() { echo -e "${GREEN}✅ SUCCESS: $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  WARNING: $1${NC}"; }
log_error() { echo -e "${RED}❌ ERROR: $1${NC}"; }

# Retry function
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
# QUICK START
# =============================================================================
start_minikube() {
    log_info "Starting Minikube..."
    
    if minikube status -p eduai-cluster 2>/dev/null | grep -q "Running"; then
        log_success "Minikube already running"
    else
        retry 3 minikube start -p eduai-cluster --driver=docker --cpus=2 --memory=4096
        log_success "Minikube started"
    fi
    
    kubectl config use-context eduai-cluster
    eval $(minikube docker-env)
    retry 5 kubectl wait --for=condition=Ready nodes --all --timeout=120s
}

# =============================================================================
# AUTO-HEAL
# =============================================================================
auto_heal() {
    log_info "Auto-healing components..."
    
    # Delete failed pods
    local failed_pods=$(kubectl get pods -n $NAMESPACE --field-selector=status.phase=Failed -o name 2>/dev/null || true)
    if [ -n "$failed_pods" ]; then
        echo "$failed_pods" | while read pod; do
            kubectl delete "$pod" -n $NAMESPACE --grace-period=0 --force || true
        done
    fi
    
    # Restart unhealthy deployments
    kubectl get deployments -n $NAMESPACE -o name | while read deployment; do
        local ready=$(kubectl get "$deployment" -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        local desired=$(kubectl get "$deployment" -n $NAMESPACE -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
        
        if [ "$ready" != "$desired" ] || [ "$ready" = "0" ]; then
            kubectl rollout restart "$deployment" -n $NAMESPACE || true
        fi
    done
    
    log_success "Auto-healing completed"
}

# =============================================================================
# TUNNEL CHECK
# =============================================================================
check_tunnel() {
    log_info "Checking Cloudflare Tunnel..."
    
    if [ ! -f "$TUNNEL_CONFIG_DIR/tunnel.pid" ] || ! kill -0 $(cat "$TUNNEL_CONFIG_DIR/tunnel.pid") 2>/dev/null; then
        log_info "Starting Cloudflare Tunnel..."
        
        # Get Minikube IP
        local minikube_ip=$(minikube ip -p eduai-cluster)
        
        # Detect tunnel credentials
        local tunnel_id=""
        local tunnel_file=""
        
        for file in "$TUNNEL_CONFIG_DIR"/*.json; do
            if [ -f "$file" ]; then
                tunnel_id=$(basename "$file" .json)
                tunnel_file="$file"
                break
            fi
        done
        
        if [ -z "$tunnel_id" ]; then
            log_error "No tunnel credentials found"
            return 1
        fi
        
        # Generate config
        cat > "$TUNNEL_CONFIG_DIR/config.yml" <<EOF
tunnel: $tunnel_id
credentials-file: $tunnel_file

ingress:
  - hostname: $DOMAIN
    service: http://$minikube_ip:30007
  - service: http_status:404
EOF
        
        # Start tunnel
        pkill -f "cloudflared tunnel run" || true
        nohup cloudflared tunnel run --config "$TUNNEL_CONFIG_DIR/config.yml" > "$TUNNEL_CONFIG_DIR/tunnel.log" 2>&1 &
        local tunnel_pid=$!
        
        sleep 5
        if kill -0 $tunnel_pid 2>/dev/null; then
            echo $tunnel_pid > "$TUNNEL_CONFIG_DIR/tunnel.pid"
            log_success "Cloudflare Tunnel started"
        else
            log_error "Failed to start Cloudflare Tunnel"
            return 1
        fi
    else
        log_success "Cloudflare Tunnel already running"
    fi
}

# =============================================================================
# STATUS OUTPUT
# =============================================================================
print_status() {
    log_info "System Status:"
    
    echo ""
    echo "📦 Pods:"
    kubectl get pods -n $NAMESPACE
    
    echo ""
    echo "🌐 Services:"
    kubectl get svc -n $NAMESPACE
    
    echo ""
    echo "🔧 Minikube IP:"
    minikube ip -p eduai-cluster
    
    echo ""
    echo "🌐 Domain:"
    echo "https://$DOMAIN"
    
    echo ""
    echo "📊 Access URLs:"
    local minikube_ip=$(minikube ip -p eduai-cluster)
    echo "Frontend: http://$minikube_ip:30007"
    echo "Backend:  http://$minikube_ip:30008"
    echo "ArgoCD:   http://$minikube_ip:32434"
    echo "Grafana:  http://$minikube_ip:31385"
}

# =============================================================================
# MAIN
# =============================================================================
main() {
    echo "⚡ AI Smart Learning Platform - Fast Runtime"
    echo "=========================================="
    
    start_minikube
    auto_heal
    check_tunnel
    print_status
}

main "$@"
