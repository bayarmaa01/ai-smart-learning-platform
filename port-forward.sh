#!/bin/bash

# =============================================================================
# Port Forwarding Script for AI Smart Learning Platform
# =============================================================================
# This script sets up port forwarding for all services to access them locally
# =============================================================================

set -e

# Configuration
NAMESPACE="eduai"
DOMAIN="ailearn.duckdns.org"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}INFO:${NC} $1"
}

log_success() {
    echo -e "${GREEN}SUCCESS:${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}WARNING:${NC} $1"
}

log_error() {
    echo -e "${RED}ERROR:${NC} $1"
}

# Check if kubectl is available
check_kubectl() {
    if ! command -v kubectl >/dev/null 2>&1; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "Cannot connect to Kubernetes cluster"
        log_info "Please ensure minikube is running: minikube start"
        exit 1
    fi
}

# Check if namespace exists
check_namespace() {
    if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        log_error "Namespace '$NAMESPACE' does not exist"
        log_info "Please run the deployment first: ./devops-smart.sh"
        exit 1
    fi
}

# Stop existing port forwards
stop_existing_forwards() {
    log_info "Stopping existing port forwards..."
    
    # Find and kill existing port-forward processes
    pkill -f "kubectl port-forward" 2>/dev/null || true
    
    # Wait a moment for processes to stop
    sleep 2
}

# Start port forwarding for all services
start_port_forwards() {
    log_info "Starting port forwarding for services..."
    
    # Create logs directory
    mkdir -p logs
    
    # Frontend port forward (3000:3000)
    log_info "Setting up frontend port forward (localhost:3000)..."
    kubectl port-forward -n "$NAMESPACE" svc/frontend 3000:3000 > logs/frontend-forward.log 2>&1 &
    FRONTEND_PID=$!
    echo $FRONTEND_PID > logs/frontend.pid
    
    # Backend port forward (5000:5000)
    log_info "Setting up backend port forward (localhost:5000)..."
    kubectl port-forward -n "$NAMESPACE" svc/backend 5000:5000 > logs/backend-forward.log 2>&1 &
    BACKEND_PID=$!
    echo $BACKEND_PID > logs/backend.pid
    
    # PostgreSQL port forward (5432:5432) - optional for local DB access
    log_info "Setting up PostgreSQL port forward (localhost:5432)..."
    kubectl port-forward -n "$NAMESPACE" svc/postgres 5432:5432 > logs/postgres-forward.log 2>&1 &
    POSTGRES_PID=$!
    echo $POSTGRES_PID > logs/postgres.pid
    
    # Redis port forward (6379:6379) - optional for local Redis access
    log_info "Setting up Redis port forward (localhost:6379)..."
    kubectl port-forward -n "$NAMESPACE" svc/redis 6379:6379 > logs/redis-forward.log 2>&1 &
    REDIS_PID=$!
    echo $REDIS_PID > logs/redis.pid
    
    # Wait for port forwards to start
    log_info "Waiting for port forwards to initialize..."
    sleep 5
    
    # Check if port forwards are running
    if kill -0 $FRONTEND_PID 2>/dev/null && kill -0 $BACKEND_PID 2>/dev/null; then
        log_success "Port forwarding started successfully"
    else
        log_error "Failed to start port forwarding"
        stop_existing_forwards
        exit 1
    fi
}

# Show access information
show_access_info() {
    echo ""
    echo "===================================================================="
    echo "Port Forwarding Active - AI Smart Learning Platform"
    echo "===================================================================="
    echo ""
    echo "LOCAL ACCESS URLS:"
    echo "=================="
    echo "Frontend:     http://localhost:3000"
    echo "Backend:      http://localhost:5000"
    echo "PostgreSQL:   localhost:5432 (for DB tools)"
    echo "Redis:        localhost:6379 (for Redis tools)"
    echo ""
    echo "PUBLIC DOMAIN:"
    echo "==============="
    echo "Domain:       https://$DOMAIN"
    echo ""
    echo "API ENDPOINTS:"
    echo "=============="
    echo "Health:       http://localhost:5000/health"
    echo "API Base:     http://localhost:5000/api/v1"
    echo ""
    echo "MONITORING:"
    echo "==========="
    echo "Process IDs saved in logs/ directory"
    echo "Logs: tail -f logs/*-forward.log"
    echo ""
    echo "TO STOP:"
    echo "========"
    echo "./port-forward.sh stop"
    echo ""
    
    # Test connectivity
    log_info "Testing connectivity..."
    sleep 2
    
    if curl -s http://localhost:3000 >/dev/null; then
        log_success "Frontend accessible at http://localhost:3000"
    else
        log_warning "Frontend not yet accessible (still starting up)"
    fi
    
    if curl -s http://localhost:5000/health >/dev/null; then
        log_success "Backend accessible at http://localhost:5000"
    else
        log_warning "Backend not yet accessible (still starting up)"
    fi
}

# Stop port forwarding
stop_port_forwards() {
    log_info "Stopping all port forwards..."
    
    # Kill processes using saved PIDs
    for service in frontend backend postgres redis; do
        if [ -f "logs/${service}.pid" ]; then
            local pid=$(cat "logs/${service}.pid")
            if kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null || true
                log_info "Stopped ${service} port forward (PID: $pid)"
            fi
            rm -f "logs/${service}.pid"
        fi
    done
    
    # Also kill any remaining kubectl port-forward processes
    pkill -f "kubectl port-forward" 2>/dev/null || true
    
    log_success "All port forwards stopped"
}

# Show status
show_status() {
    echo "Port Forwarding Status:"
    echo "======================"
    
    for service in frontend backend postgres redis; do
        if [ -f "logs/${service}.pid" ]; then
            local pid=$(cat "logs/${service}.pid")
            if kill -0 "$pid" 2>/dev/null; then
                echo "  $service: RUNNING (PID: $pid)"
            else
                echo "  $service: STOPPED"
                rm -f "logs/${service}.pid"
            fi
        else
            echo "  $service: STOPPED"
        fi
    done
}

# Main function
main() {
    case "${1:-start}" in
        "start")
            check_kubectl
            check_namespace
            stop_existing_forwards
            start_port_forwards
            show_access_info
            ;;
        "stop")
            stop_port_forwards
            ;;
        "status")
            show_status
            ;;
        "restart")
            stop_port_forwards
            sleep 2
            main start
            ;;
        "help"|"-h"|"--help")
            echo "Usage: $0 [start|stop|restart|status|help]"
            echo ""
            echo "Commands:"
            echo "  start   - Start port forwarding for all services"
            echo "  stop    - Stop all port forwarding"
            echo "  restart - Restart port forwarding"
            echo "  status  - Show current status"
            echo "  help    - Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 start    # Start port forwarding"
            echo "  $0 stop     # Stop port forwarding"
            echo "  $0 status   # Check status"
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Handle script interruption
trap 'log_warning "Script interrupted"; stop_port_forwards; exit 1' INT TERM

# Run main function
main "$@"
