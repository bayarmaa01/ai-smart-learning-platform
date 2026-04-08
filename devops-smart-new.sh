#!/bin/bash

# AI Smart Learning Platform - Production DevOps Script
# Supports WSL2 + Minikube + Cloudflare Tunnel
# Usage: ./devops-smart.sh [full|fast]

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
NAMESPACE="eduai"
DOMAIN="ailearn.duckdns.org"
TUNNEL_NAME="eduai-tunnel"
FRONTEND_NODEPORT=30007
BACKEND_NODEPORT=30008
MINIKUBE_IP=""

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${PURPLE}[STEP]${NC} $1"; }

# Get Minikube IP
get_minikube_ip() {
    MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "")
    if [[ -z "$MINIKUBE_IP" ]]; then
        log_error "Failed to get Minikube IP"
        return 1
    fi
    log_info "Minikube IP: $MINIKUBE_IP"
}

# Wait for pods
wait_for_pods() {
    log_step "Waiting for pods to be ready..."
    local timeout=300
    local interval=5
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        local ready=$(minikube kubectl -- get pods -n $NAMESPACE --no-headers | awk '{print $2}' | grep -c '1/1' || true)
        local total=$(minikube kubectl -- get pods -n $NAMESPACE --no-headers | wc -l)
        
        if [[ $ready -eq $total ]] && [[ $ready -gt 0 ]]; then
            log_success "All $ready pods are ready"
            return 0
        fi
        
        log_info "Pods ready: $ready/$total (waiting ${interval}s...)"
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    log_error "Timeout waiting for pods"
    return 1
}

# Initialize database
init_database() {
    log_step "Initializing database..."
    
    # Check if tables exist
    local tables=$(minikube kubectl -- exec -n $NAMESPACE deployment/postgres -- psql -U postgres -d eduai -tAc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public'" 2>/dev/null || echo "0")
    
    if [[ $tables -gt 0 ]]; then
        log_info "Database already has $tables tables"
        return 0
    fi
    
    # Copy and execute schema
    minikube kubectl -- cp backend/src/db/schema.sql -n $NAMESPACE deployment/postgres:/tmp/schema.sql
    minikube kubectl -- exec -n $NAMESPACE deployment/postgres -- psql -U postgres -d eduai -f /tmp/schema.sql
    
    log_success "Database initialized with schema"
}

# Create default user
create_default_user() {
    log_step "Creating default user..."
    
    # Check if user exists
    local exists=$(minikube kubectl -- exec -n $NAMESPACE deployment/postgres -- psql -U postgres -d eduai -tAc "SELECT COUNT(*) FROM users WHERE email='test@test.com'" 2>/dev/null || echo "0")
    
    if [[ $exists -gt 0 ]]; then
        log_info "Default user already exists"
        return 0
    fi
    
    # Hash password and create user
    local hashed_password=$(echo -n "123456" | openssl dgst -sha256 | cut -d' ' -f2)
    
    minikube kubectl -- exec -n $NAMESPACE deployment/postgres -- psql -U postgres -d eduai -c "
        INSERT INTO users (email, password_hash, first_name, last_name, email_verified, is_active, created_at, updated_at)
        VALUES ('test@test.com', '$hashed_password', 'Test', 'User', true, true, NOW(), NOW());
    "
    
    log_success "Default user created: test@test.com / 123456"
}

# Start Cloudflare tunnel
start_tunnel() {
    log_step "Starting Cloudflare tunnel..."
    
    # Kill existing tunnel
    pkill -f cloudflared || true
    sleep 2
    
    # Start tunnel
    nohup cloudflared tunnel --url http://localhost:3000 --name $TUNNEL_NAME > /tmp/cloudflared.log 2>&1 &
    local tunnel_pid=$!
    
    sleep 5
    
    if kill -0 $tunnel_pid 2>/dev/null; then
        log_success "Cloudflare tunnel started (PID: $tunnel_pid)"
        
        # Set up DNS
        if ! cloudflared tunnel route dns $TUNNEL_NAME $DOMAIN >/dev/null 2>&1; then
            log_warning "DNS route may already exist or failed"
        fi
        
        log_info "Domain: https://$DOMAIN"
    else
        log_error "Failed to start Cloudflare tunnel"
        return 1
    fi
}

# Start port forwarding
start_port_forward() {
    log_step "Starting port forwarding..."
    
    # Kill existing forwards
    pkill -f "kubectl port-forward" || true
    sleep 2
    
    # Start port forwarding
    minikube kubectl -- port-forward -n $NAMESPACE svc/frontend 3000:3000 > /tmp/port-forward-frontend.log 2>&1 &
    local frontend_pid=$!
    
    minikube kubectl -- port-forward -n $NAMESPACE svc/backend 5000:5000 > /tmp/port-forward-backend.log 2>&1 &
    local backend_pid=$!
    
    sleep 3
    
    if kill -0 $frontend_pid 2>/dev/null && kill -0 $backend_pid 2>/dev/null; then
        log_success "Port forwarding started"
        log_info "Frontend: http://localhost:3000"
        log_info "Backend: http://localhost:5000"
    else
        log_error "Failed to start port forwarding"
        return 1
    fi
}

# Verify services
verify_services() {
    log_step "Verifying services..."
    
    # Check NodePort access
    get_minikube_ip
    if [[ -n "$MINIKUBE_IP" ]]; then
        if curl -s --max-time 5 http://$MINIKUBE_IP:$FRONTEND_NODEPORT >/dev/null 2>&1; then
            log_success "Frontend NodePort accessible: http://$MINIKUBE_IP:$FRONTEND_NODEPORT"
        else
            log_warning "Frontend NodePort not accessible from browser (WSL limitation)"
            log_info "Use: http://localhost:3000 (port forwarding)"
        fi
        
        if curl -s --max-time 5 http://$MINIKUBE_IP:$BACKEND_NODEPORT/health >/dev/null 2>&1; then
            log_success "Backend NodePort accessible: http://$MINIKUBE_IP:$BACKEND_NODEPORT"
        else
            log_warning "Backend NodePort not accessible from browser (WSL limitation)"
            log_info "Use: http://localhost:5000 (port forwarding)"
        fi
    fi
    
    # Check domain
    if curl -s --max-time 10 https://$DOMAIN >/dev/null 2>&1; then
        log_success "Domain accessible: https://$DOMAIN"
    else
        log_warning "Domain not accessible yet (tunnel starting...)"
    fi
    
    # Check Prometheus targets
    log_info "Checking Prometheus targets..."
    local prometheus_up=$(curl -s http://localhost:9090/api/v1/targets 2>/dev/null | jq -r '.data.activeTargets[] | select(.health=="up") | .labels.job' | wc -l || echo "0")
    local prometheus_total=$(curl -s http://localhost:9090/api/v1/targets 2>/dev/null | jq -r '.data.activeTargets | length' || echo "0")
    
    log_info "Prometheus targets: $prometheus_up/$prometheus_total up"
    
    if [[ $prometheus_up -eq $prometheus_total ]] && [[ $prometheus_total -gt 0 ]]; then
        log_success "All Prometheus targets are UP"
    else
        log_warning "Some Prometheus targets are DOWN"
    fi
}

# Full deployment
full_deployment() {
    log_step "Starting FULL deployment..."
    
    # Start Minikube
    if ! minikube status >/dev/null 2>&1; then
        log_info "Starting Minikube..."
        minikube start --driver=docker --memory=4096 --cpus=2
    fi
    
    # Set Docker environment
    eval $(minikube docker-env)
    
    # Build images
    log_info "Building Docker images..."
    docker build -t eduai-frontend:latest ./frontend
    docker build -t eduai-backend:latest ./backend
    
    # Apply manifests
    log_info "Applying Kubernetes manifests..."
    minikube kubectl -- apply -f k8s/namespace.yaml
    minikube kubectl -- apply -f k8s/
    
    # Wait for pods
    wait_for_pods
    
    # Initialize database
    init_database
    
    # Create default user
    create_default_user
    
    # Start services
    start_tunnel
    start_port_forward
    
    # Verify
    verify_services
    
    log_success "FULL deployment completed!"
    log_info "Access URLs:"
    log_info "  Frontend: http://localhost:3000"
    log_info "  Backend:  http://localhost:5000"
    log_info "  Domain:   https://$DOMAIN"
    log_info "  Prometheus: http://localhost:9090"
}

# Fast deployment
fast_deployment() {
    log_step "Starting FAST deployment..."
    
    # Restart pods
    minikube kubectl -- rollout restart deployment -n $NAMESPACE
    wait_for_pods
    
    # Restart services
    start_tunnel
    start_port_forward
    
    # Verify
    verify_services
    
    log_success "FAST deployment completed!"
}

# Main script
main() {
    local mode=${1:-"full"}
    
    log_info "AI Smart Learning Platform - DevOps Script"
    log_info "Mode: $mode"
    log_info "Namespace: $NAMESPACE"
    log_info "Domain: $DOMAIN"
    
    case $mode in
        "full")
            full_deployment
            ;;
        "fast")
            fast_deployment
            ;;
        *)
            log_error "Invalid mode: $mode"
            log_info "Usage: $0 [full|fast]"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
