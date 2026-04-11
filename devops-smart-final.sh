#!/bin/bash

# AI Smart Learning Platform - Complete Deployment Script
# Usage: ./devops-smart-final.sh

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
FRONTEND_NODEPORT=30007
BACKEND_NODEPORT=30008
MINIKUBE_IP=""

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${PURPLE}[STEP]${NC} $1"; }

# Error handling
trap 'log_error "Script failed at line $LINENO"' ERR

# Utility functions
retry() {
    local retries=$1
    shift
    local count=0
    until "$@"; do
        exit_code=$?
        count=$((count + 1))
        if [ $count -lt $retries ]; then
            log_warning "Command failed (attempt $count/$retries). Retrying in ${count}s..."
            sleep $count
        else
            log_error "Command failed after $retries attempts"
            return $exit_code
        fi
    done
}

wait_for_pods() {
    local namespace=$1
    local timeout=${2:-300}
    local label=${3:-""}
    
    log_info "Waiting for pods in namespace '$namespace'..."
    local selector=""
    if [ -n "$label" ]; then
        selector="-l $label"
    fi
    
    minikube kubectl -- wait --for=condition=Ready pods -n "$namespace" $selector --timeout="${timeout}s" || {
        log_warning "Some pods are not ready within ${timeout}s"
        return 1
    }
}

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."
    
    # Check if minikube is installed
    if ! command -v minikube >/dev/null 2>&1; then
        log_error "Minikube is not installed. Please install it first."
        exit 1
    fi
    
    # Check if kubectl is installed
    if ! command -v kubectl >/dev/null 2>&1; then
        log_error "kubectl is not installed. Please install it first."
        exit 1
    fi
    
    # Check if docker is installed
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker is not installed. Please install it first."
        exit 1
    fi
    
    # Check if Ollama is running
    if ! curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
        log_warning "Ollama is not running on localhost:11434"
        log_info "Please start Ollama first: ollama serve"
        log_info "And pull the model: ollama pull gemma4:31b"
    else
        log_success "Ollama is running"
        # Check if gemma4:31b model is available
        if ! curl -s http://localhost:11434/api/tags | grep -q "gemma4:31b"; then
            log_warning "gemma4:31b model not found. Pulling it now..."
            ollama pull gemma4:31b || {
                log_error "Failed to pull gemma4:31b model"
                exit 1
            }
        fi
        log_success "gemma4:31b model is available"
    fi
    
    log_success "Prerequisites check completed"
}

# Setup Minikube cluster
setup_minikube() {
    log_step "Setting up Minikube cluster..."
    
    # Start minikube if not running
    if ! minikube status >/dev/null 2>&1; then
        log_info "Starting Minikube..."
        retry 3 minikube start --driver=docker --cpus=4 --memory=4096 --disk-size=20g
    fi
    
    # Set context
    kubectl config use-context minikube >/dev/null 2>&1 || true
    
    # Setup Docker environment
    eval $(minikube docker-env)
    
    # Enable addons
    minikube addons enable ingress >/dev/null 2>&1 || true
    minikube addons enable metrics-server >/dev/null 2>&1 || true
    
    log_success "Minikube is ready"
}

# Build Docker images
build_images() {
    log_step "Building Docker images..."
    
    # Build backend
    log_info "Building backend image..."
    if ! docker build -t eduai-backend:latest ./backend; then
        log_error "Failed to build backend image"
        exit 1
    fi
    log_success "Backend image built"
    
    # Build frontend
    log_info "Building frontend image..."
    if ! docker build -t eduai-frontend:latest ./frontend; then
        log_error "Failed to build frontend image"
        exit 1
    fi
    log_success "Frontend image built"
    
    log_success "All images built successfully"
}

# Deploy infrastructure
deploy_infrastructure() {
    log_step "Deploying infrastructure..."
    
    # Create namespace
    kubectl apply -f k8s/namespace-fixed.yaml
    
    # Deploy PostgreSQL
    log_info "Deploying PostgreSQL..."
    kubectl apply -f k8s/postgres-deployment-fixed.yaml
    
    # Deploy Redis
    log_info "Deploying Redis..."
    kubectl apply -f k8s/redis-deployment-fixed.yaml
    
    # Wait for database to be ready
    wait_for_pods "$NAMESPACE" 120 "app=postgres"
    wait_for_pods "$NAMESPACE" 60 "app=redis"
    
    log_success "Infrastructure deployed"
}

# Deploy applications
deploy_applications() {
    log_step "Deploying applications..."
    
    # Deploy backend
    log_info "Deploying backend..."
    kubectl apply -f k8s/backend-deployment-fixed.yaml
    
    # Deploy frontend
    log_info "Deploying frontend..."
    kubectl apply -f k8s/frontend-deployment-fixed.yaml
    
    # Wait for applications to be ready
    wait_for_pods "$NAMESPACE" 180 "app=backend"
    wait_for_pods "$NAMESPACE" 120 "app=frontend"
    
    log_success "Applications deployed"
}

# Deploy monitoring stack
deploy_monitoring() {
    log_step "Deploying monitoring stack..."
    
    # Deploy service accounts and RBAC
    log_info "Setting up monitoring RBAC..."
    kubectl apply -f k8s/service-accounts-monitoring.yaml
    
    # Deploy complete monitoring stack
    log_info "Deploying Prometheus, Grafana, AlertManager..."
    kubectl apply -f k8s/monitoring-complete.yaml
    
    # Wait for monitoring services to be ready
    wait_for_pods "monitoring" 300 "app=prometheus"
    wait_for_pods "monitoring" 180 "app=grafana"
    wait_for_pods "monitoring" 120 "app=node-exporter"
    
    log_success "Monitoring stack deployed"
}

# Deploy ArgoCD
deploy_argocd() {
    log_step "Deploying ArgoCD for GitOps..."
    
    # Deploy ArgoCD
    log_info "Deploying ArgoCD server and applications..."
    kubectl apply -f k8s/argocd-complete.yaml
    
    # Wait for ArgoCD to be ready
    wait_for_pods "argocd" 300 "app.kubernetes.io/name=argocd-server"
    
    log_success "ArgoCD deployed"
}

# Setup port forwarding
setup_port_forwarding() {
    log_step "Setting up port forwarding..."
    
    # Kill existing port forwards
    pkill -f "kubectl port-forward" || true
    sleep 2
    
    # Start port forwarding in background
    log_info "Starting port forwarding for frontend..."
    kubectl port-forward -n "$NAMESPACE" svc/frontend-nodeport 3000:3000 &
    FRONTEND_PID=$!
    
    log_info "Starting port forwarding for backend..."
    kubectl port-forward -n "$NAMESPACE" svc/backend-nodeport 5000:5000 &
    BACKEND_PID=$!
    
    log_info "Starting port forwarding for Grafana..."
    kubectl port-forward -n monitoring svc/grafana 3002:3000 &
    GRAFANA_PID=$!
    
    log_info "Starting port forwarding for Prometheus..."
    kubectl port-forward -n monitoring svc/prometheus 9092:9090 &
    PROMETHEUS_PID=$!
    
    log_info "Starting port forwarding for ArgoCD..."
    kubectl port-forward -n argocd svc/argocd-server 18081:8080 &
    ARGOCD_PID=$!
    
    # Wait a moment for port forwarding to establish
    sleep 5
    
    # Save PIDs for cleanup
    echo $FRONTEND_PID > /tmp/frontend-portforward.pid
    echo $BACKEND_PID > /tmp/backend-portforward.pid
    echo $GRAFANA_PID > /tmp/grafana-portforward.pid
    echo $PROMETHEUS_PID > /tmp/prometheus-portforward.pid
    echo $ARGOCD_PID > /tmp/argocd-portforward.pid
    
    log_success "Port forwarding established"
}

# Test services
test_services() {
    log_step "Testing services..."
    
    # Test backend health
    log_info "Testing backend health..."
    if curl -s http://localhost:5000/health | grep -q "healthy"; then
        log_success "Backend health check passed"
    else
        log_error "Backend health check failed"
        return 1
    fi
    
    # Test AI endpoint
    log_info "Testing AI chat endpoint..."
    if curl -s -X POST http://localhost:5000/api/chat \
        -H "Content-Type: application/json" \
        -d '{"message":"Hello, how are you?"}' | grep -q "success"; then
        log_success "AI chat endpoint working"
    else
        log_warning "AI chat endpoint test failed (may need Ollama running)"
    fi
    
    # Test frontend
    log_info "Testing frontend..."
    if curl -s http://localhost:3000 | grep -q "html\|HTML"; then
        log_success "Frontend is accessible"
    else
        log_error "Frontend test failed"
        return 1
    fi
    
    log_success "Service tests completed"
}

# Test services
test_services() {
    log_step "Testing services..."
    
    # Test backend health
    log_info "Testing backend health..."
    if curl -s http://localhost:5000/health | grep -q "healthy"; then
        log_success "Backend health check passed"
    else
        log_error "Backend health check failed"
        return 1
    fi
    
    # Test AI endpoint
    log_info "Testing AI chat endpoint..."
    if curl -s -X POST http://localhost:5000/api/chat \
        -H "Content-Type: application/json" \
        -d '{"message":"Hello, how are you?"}' | grep -q "success"; then
        log_success "AI chat endpoint working"
    else
        log_warning "AI chat endpoint test failed (may need Ollama running)"
    fi
    
    # Test frontend
    log_info "Testing frontend..."
    if curl -s http://localhost:3000 | grep -q "html\|HTML"; then
        log_success "Frontend is accessible"
    else
        log_error "Frontend test failed"
        return 1
    fi
    
    # Run comprehensive test suite
    log_info "Running comprehensive test suite..."
    if command -v node >/dev/null 2>&1 && [ -f "test-platform.js" ]; then
        if node test-platform.js; then
            log_success "Comprehensive test suite passed"
        else
            log_warning "Some tests failed, but platform may still be functional"
        fi
    else
        log_warning "Node.js or test script not found, skipping comprehensive tests"
    fi
    
    log_success "Service tests completed"
}

# Show access information
show_access_info() {
    echo ""
    echo "🌐 AI SMART LEARNING PLATFORM IS READY!"
    echo "======================================"
    echo ""
    echo "📱 LOCAL ACCESS:"
    echo "  Frontend:  http://localhost:3000"
    echo "  Backend:   http://localhost:5000"
    echo "  AI Chat:   http://localhost:3000/ai-chat"
    echo ""
    echo "📊 MONITORING & DEVOPS:"
    echo "  Grafana:    http://localhost:3002 (admin/admin)"
    echo "  Prometheus: http://localhost:9092"
    echo "  ArgoCD:     http://localhost:18081 (admin/admin123)"
    echo ""
    echo "🤖 AI SERVICES:"
    echo "  Ollama:    http://localhost:11434"
    echo "  Model:      gemma4:31b"
    echo ""
    echo "📊 KUBERNETES:"
    echo "  Namespace:  $NAMESPACE"
    echo "  Minikube:   $(minikube ip)"
    echo ""
    echo "🔧 USEFUL COMMANDS:"
    echo "  View pods:     kubectl get pods -n $NAMESPACE"
    echo "  View logs:     kubectl logs -n $NAMESPACE -l app=backend"
    echo "  Monitoring:    kubectl get pods -n monitoring"
    echo "  ArgoCD:       kubectl get applications -n argocd"
    echo "  Stop forward:  kill \$(cat /tmp/*-portforward.pid)"
    echo "  Run tests:     node test-platform.js"
    echo ""
    echo "✅ PLATFORM WITH FULL MONITORING IS OPERATIONAL!"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up..."
    # Kill all port forwards
    for pidfile in /tmp/*-portforward.pid; do
        if [ -f "$pidfile" ]; then
            kill $(cat "$pidfile") 2>/dev/null || true
            rm -f "$pidfile"
        fi
    done
}

# Main execution
main() {
    log_info "🚀 Starting AI Smart Learning Platform Deployment..."
    
    # Setup cleanup trap
    trap cleanup EXIT
    
    # Execute deployment steps
    check_prerequisites
    setup_minikube
    build_images
    deploy_infrastructure
    deploy_applications
    deploy_monitoring
    deploy_argocd
    setup_port_forwarding
    test_services
    show_access_info
    
    log_success "🎉 Deployment completed successfully!"
}

# Handle script interruption
trap 'log_error "Script interrupted"; cleanup; exit 1' INT TERM

# Run main function
main "$@"
