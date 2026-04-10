#!/bin/bash

# AI Smart Learning Platform - Production DevOps Script with Ingress
# Supports HTTPS domain with Let's Encrypt certificates
# Usage: ./devops-smart-ingress.sh [full|fast]

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
EMAIL="bayarmaa@example.com"
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

# Install NGINX Ingress Controller
install_ingress_controller() {
    log_step "Installing NGINX Ingress Controller..."
    
    if minikube kubectl -- get ingressclass nginx >/dev/null 2>&1; then
        log_info "NGINX Ingress Controller already installed"
        return 0
    fi
    
    # Add Helm repository
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update
    
    # Install NGINX Ingress Controller
    helm install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --set controller.replicaCount=1 \
        --set controller.nodeSelector."kubernetes\.io/os"=linux \
        --set controller.ingressClassResource.name=nginx \
        --set controller.ingressClassResource.controllerValue=k8s.io/ingress-nginx \
        --set controller.ingressClassResource.enabled=true \
        --set controller.admissionWebhooks.enabled=false \
        --set controller.service.type=NodePort \
        --set controller.service.httpPort.nodePort=30080 \
        --set controller.service.httpsPort.nodePort=30443 \
        --set controller.config.use-forwarded-headers="true" \
        --set controller.config.compute-full-forwarded-for="true"
    
    log_success "NGINX Ingress Controller installed"
}

# Install cert-manager
install_cert_manager() {
    log_step "Installing cert-manager..."
    
    if minikube kubectl -- get namespace cert-manager >/dev/null 2>&1; then
        log_info "cert-manager already installed"
        return 0
    fi
    
    # Install cert-manager
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml
    
    # Wait for cert-manager pods
    log_info "Waiting for cert-manager pods..."
    local timeout=120
    local interval=5
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        local ready=$(minikube kubectl -- get pods -n cert-manager --no-headers | awk '{print $2}' | grep -c '1/1' || true)
        local total=$(minikube kubectl -- get pods -n cert-manager --no-headers | wc -l)
        
        if [[ $ready -eq $total ]] && [[ $ready -gt 0 ]]; then
            log_success "All cert-manager pods are ready"
            break
        fi
        
        log_info "cert-manager pods ready: $ready/$total (waiting ${interval}s...)"
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    log_success "cert-manager installed"
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

# Apply ClusterIssuer
apply_cluster_issuer() {
    log_step "Applying ClusterIssuer..."
    
    # Update email in ClusterIssuer
    sed "s/bayarmaa@example.com/$EMAIL/g" k8s/cluster-issuer.yaml | minikube kubectl -- apply -f -
    
    log_success "ClusterIssuer applied"
}

# Apply Ingress
apply_ingress() {
    log_step "Applying Ingress..."
    
    minikube kubectl -- apply -f k8s/ingress.yaml
    minikube kubectl -- apply -f k8s/ai-service.yaml
    
    log_success "Ingress and AI service applied"
}

# Verify certificate
verify_certificate() {
    log_step "Verifying certificate..."
    
    log_info "Waiting for certificate to be issued..."
    local timeout=300
    local interval=10
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        local cert_status=$(minikube kubectl -- get certificate ailearn-tls -n $NAMESPACE -o jsonpath='{.status.conditions[0].status}' 2>/dev/null || echo "Unknown")
        
        if [[ "$cert_status" == "True" ]]; then
            log_success "Certificate issued successfully"
            return 0
        fi
        
        log_info "Certificate status: $cert_status (waiting ${interval}s...)"
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    log_warning "Certificate may still be processing"
}

# Verify services
verify_services() {
    log_step "Verifying services..."
    
    # Check Ingress
    get_minikube_ip
    if [[ -n "$MINIKUBE_IP" ]]; then
        log_info "Testing HTTP access..."
        if curl -s --max-time 10 http://$MINIKUBE_IP:30080 >/dev/null 2>&1; then
            log_success "HTTP Ingress accessible: http://$MINIKUBE_IP:30080"
        else
            log_warning "HTTP Ingress not accessible"
        fi
        
        log_info "Testing HTTPS access..."
        if curl -s --max-time 10 https://$DOMAIN >/dev/null 2>&1; then
            log_success "HTTPS domain accessible: https://$DOMAIN"
        else
            log_warning "HTTPS domain not accessible yet (certificate may be processing)"
        fi
    fi
    
    # Check certificate
    log_info "Certificate details:"
    minikube kubectl -- get certificate ailearn-tls -n $NAMESPACE || log_warning "Certificate not found"
    
    # Check Ingress
    log_info "Ingress details:"
    minikube kubectl -- get ingress ailearn-ingress -n $NAMESPACE || log_warning "Ingress not found"
    
    # Check AI service
    log_info "Testing AI service..."
    if minikube kubectl -- exec -n $NAMESPACE deployment/ai-service -- curl -s http://localhost:8000/health >/dev/null 2>&1; then
        log_success "AI service is healthy"
    else
        log_warning "AI service not responding"
    fi
}

# Full deployment
full_deployment() {
    log_step "Starting FULL deployment with HTTPS..."
    
    # Start Minikube
    if ! minikube status >/dev/null 2>&1; then
        log_info "Starting Minikube..."
        minikube start --driver=docker --memory=4096 --cpus=2
    fi
    
    # Enable addons
    minikube addons enable ingress
    minikube addons enable ingress-dns
    
    # Set Docker environment
    eval $(minikube docker-env)
    
    # Install Ingress Controller
    install_ingress_controller
    
    # Install cert-manager
    install_cert_manager
    
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
    
    # Apply ClusterIssuer and Ingress
    apply_cluster_issuer
    apply_ingress
    
    # Verify certificate
    verify_certificate
    
    # Verify services
    verify_services
    
    log_success "FULL HTTPS deployment completed!"
    log_info "Access URLs:"
    log_info "  HTTPS Domain: https://$DOMAIN"
    log_info "  HTTP (temp):   http://$MINIKUBE_IP:30080"
    log_info "  HTTPS (temp):   https://$MINIKUBE_IP:30443"
    log_info ""
    log_info "Default user: test@test.com / 123456"
    log_info ""
    log_info "Debug commands:"
    log_info "  kubectl get ingress -n $NAMESPACE"
    log_info "  kubectl describe certificate ailearn-tls -n $NAMESPACE"
    log_info "  kubectl logs -n cert-manager deployment/cert-manager"
}

# Fast deployment
fast_deployment() {
    log_step "Starting FAST deployment..."
    
    # Restart pods
    minikube kubectl -- rollout restart deployment -n $NAMESPACE
    wait_for_pods
    
    # Verify services
    verify_services
    
    log_success "FAST deployment completed!"
}

# Main script
main() {
    local mode=${1:-"full"}
    
    log_info "AI Smart Learning Platform - HTTPS DevOps Script"
    log_info "Mode: $mode"
    log_info "Domain: $DOMAIN"
    log_info "Email: $EMAIL"
    
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
