#!/bin/bash

# =============================================================================
# Port Forwarding Setup for AI Smart Learning Platform
# Sets up port forwarding for all services to localhost access
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="eduai"
MONITORING_NAMESPACE="monitoring"
ARGOCD_NAMESPACE="eduai-argocd"

# Port mappings
FRONTEND_PORT=3200
BACKEND_PORT=4200
AI_PORT=5200
GRAFANA_PORT=3004
PROMETHEUS_PORT=9093
ARGOCD_PORT=18080

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

# Cleanup function
cleanup() {
    log "Cleaning up port forwarding processes..."
    pkill -f "kubectl port-forward" || true
    success "Port forwarding stopped"
}

# Check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is not installed or not in PATH"
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        error "Kubernetes cluster is not accessible"
    fi
    
    success "kubectl is ready"
}

# Check if services exist
check_services() {
    log "Checking if services exist..."
    
    # Check core services
    if ! kubectl get svc frontend-nodeport -n $NAMESPACE &> /dev/null; then
        error "Frontend service not found in namespace $NAMESPACE"
    fi
    
    if ! kubectl get svc backend-nodeport -n $NAMESPACE &> /dev/null; then
        error "Backend service not found in namespace $NAMESPACE"
    fi
    
    # Check monitoring services
    if ! kubectl get svc kube-prometheus-stack-grafana -n $MONITORING_NAMESPACE &> /dev/null; then
        warning "Grafana service not found in namespace $MONITORING_NAMESPACE"
    fi
    
    if ! kubectl get svc kube-prometheus-stack-prometheus -n $MONITORING_NAMESPACE &> /dev/null; then
        warning "Prometheus service not found in namespace $MONITORING_NAMESPACE"
    fi
    
    success "Service check completed"
}

# Setup port forwarding
setup_port_forwarding() {
    log "Setting up port forwarding..."
    
    # Kill existing port forwards
    cleanup
    
    # Start port forwarding in background
    log "Starting port forwarding for Frontend..."
    kubectl port-forward -n $NAMESPACE svc/frontend-nodeport $FRONTEND_PORT:3000 &
    local frontend_pid=$!
    echo $frontend_pid > /tmp/frontend-portforward.pid
    
    log "Starting port forwarding for Backend..."
    kubectl port-forward -n $NAMESPACE svc/backend-nodeport $BACKEND_PORT:5000 &
    local backend_pid=$!
    echo $backend_pid > /tmp/backend-portforward.pid
    
    log "Starting port forwarding for AI Services..."
    kubectl port-forward -n $NAMESPACE svc/backend-nodeport $AI_PORT:5000 &
    local ai_pid=$!
    echo $ai_pid > /tmp/ai-portforward.pid
    
    # Monitoring services (if available)
    if kubectl get svc kube-prometheus-stack-grafana -n $MONITORING_NAMESPACE &> /dev/null; then
        log "Starting port forwarding for Grafana..."
        kubectl port-forward -n $MONITORING_NAMESPACE svc/kube-prometheus-stack-grafana $GRAFANA_PORT:3000 &
        local grafana_pid=$!
        echo $grafana_pid > /tmp/grafana-portforward.pid
    fi
    
    if kubectl get svc kube-prometheus-stack-prometheus -n $MONITORING_NAMESPACE &> /dev/null; then
        log "Starting port forwarding for Prometheus..."
        kubectl port-forward -n $MONITORING_NAMESPACE svc/kube-prometheus-stack-prometheus $PROMETHEUS_PORT:9090 &
        local prometheus_pid=$!
        echo $prometheus_pid > /tmp/prometheus-portforward.pid
    fi
    
    # ArgoCD (if available)
    if kubectl get svc argocd-server-nodeport -n $ARGOCD_NAMESPACE &> /dev/null; then
        log "Starting port forwarding for ArgoCD..."
        kubectl port-forward -n $ARGOCD_NAMESPACE svc/argocd-server-nodeport $ARGOCD_PORT:8080 &
        local argocd_pid=$!
        echo $argocd_pid > /tmp/argocd-portforward.pid
    fi
    
    # Wait a moment for port forwarding to establish
    sleep 3
    
    success "Port forwarding established"
}

# Test port forwarding
test_port_forwarding() {
    log "Testing port forwarding..."
    
    # Test frontend
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:$FRONTEND_PORT | grep -q "200"; then
        success "Frontend accessible on http://localhost:$FRONTEND_PORT"
    else
        warning "Frontend not accessible on http://localhost:$FRONTEND_PORT"
    fi
    
    # Test backend
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:$BACKEND_PORT/health | grep -q "200\|404"; then
        success "Backend accessible on http://localhost:$BACKEND_PORT"
    else
        warning "Backend not accessible on http://localhost:$BACKEND_PORT"
    fi
    
    # Test Grafana
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:$GRAFANA_PORT | grep -q "200\|302"; then
        success "Grafana accessible on http://localhost:$GRAFANA_PORT"
    else
        warning "Grafana not accessible on http://localhost:$GRAFANA_PORT"
    fi
}

# Show access information
show_access_info() {
    echo ""
    echo "==============================================="
    echo "  PORT FORWARDING ACCESS INFORMATION"
    echo "==============================================="
    echo ""
    echo "AI SMART LEARNING PLATFORM:"
    echo "  Frontend:     http://localhost:$FRONTEND_PORT"
    echo "  Backend:      http://localhost:$BACKEND_PORT"
    echo "  AI Chat:      http://localhost:$AI_PORT/ai-chat"
    echo ""
    echo "MONITORING:"
    echo "  Grafana:      http://localhost:$GRAFANA_PORT (admin/admin)"
    echo "  Prometheus:   http://localhost:$PROMETHEUS_PORT"
    echo ""
    echo "DEVOPS:"
    echo "  ArgoCD:       http://localhost:$ARGOCD_PORT (admin/admin123)"
    echo ""
    echo "AI SERVICES:"
    echo "  Ollama:       http://localhost:11434"
    echo ""
    echo "Commands:"
    echo "  Stop all:     ./port-forward-setup.sh stop"
    echo "  Status:       ./port-forward-setup.sh status"
    echo "  Restart:      ./port-forward-setup.sh restart"
    echo ""
    echo "==============================================="
}

# Show status
show_status() {
    log "Checking port forwarding status..."
    
    echo ""
    echo "Active Port Forwarding Processes:"
    ps aux | grep "kubectl port-forward" | grep -v grep || echo "No port forwarding processes found"
    
    echo ""
    echo "Port Status:"
    
    # Test each port
    for port in $FRONTEND_PORT $BACKEND_PORT $AI_PORT $GRAFANA_PORT $PROMETHEUS_PORT $ARGOCD_PORT; do
        if curl -s -o /dev/null -w "%{http_code}" http://localhost:$port | grep -q "200\|302\|404"; then
            echo "  Port $port: ${GREEN}ACTIVE${NC}"
        else
            echo "  Port $port: ${RED}INACTIVE${NC}"
        fi
    done
}

# Help function
show_help() {
    cat <<EOF
Port Forwarding Setup for AI Smart Learning Platform

USAGE:
    $0 [COMMAND]

COMMANDS:
    start       Start port forwarding for all services
    stop        Stop all port forwarding processes
    status      Show current port forwarding status
    restart     Restart port forwarding
    test        Test port forwarding connectivity
    help        Show this help message

EXAMPLES:
    $0 start    # Start port forwarding
    $0 stop     # Stop port forwarding
    $0 status   # Show status

EOF
}

# Main execution
main() {
    case "${1:-start}" in
        start)
            check_kubectl
            check_services
            setup_port_forwarding
            test_port_forwarding
            show_access_info
            ;;
        stop)
            cleanup
            ;;
        status)
            show_status
            ;;
        restart)
            cleanup
            sleep 2
            main start
            ;;
        test)
            test_port_forwarding
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

# Set up trap for cleanup
trap cleanup EXIT

# Execute main function
main "$@"
