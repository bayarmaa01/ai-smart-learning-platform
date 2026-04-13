#!/bin/bash

# =============================================================================
# Deployment Script with Auto Versioning
# Automatically versions frontend builds and updates Kubernetes
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Configuration
NAMESPACE="eduai"
FRONTEND_IMAGE="eduai-backend:latest"  # This should be frontend image
BACKEND_IMAGE="eduai-backend:latest"

# Get current version
get_current_version() {
    if [ -f "frontend/package.json" ]; then
        grep -o '"version": "[^"]*' frontend/package.json | cut -d'"' -f4
    else
        echo "1.0.0"
    fi
}

# Update version
update_version() {
    local current_version=$(get_current_version)
    local new_version="${current_version}+$(date +%Y%m%d%H%M%S)"
    
    log "Updating version from $current_version to $new_version"
    
    # Update package.json
    if [ -f "frontend/package.json" ]; then
        sed -i "s/\"version\": \"$current_version\"/\"version\": \"$new_version\"/" frontend/package.json
        success "Version updated to $new_version"
    fi
    
    echo $new_version
}

# Build frontend with versioning
build_frontend() {
    log "Building frontend with auto versioning..."
    
    cd frontend
    
    # Update version first
    NEW_VERSION=$(update_version)
    
    # Install dependencies
    npm ci
    
    # Build with version
    npm run build:prod
    
    cd ..
    
    success "Frontend built with version $NEW_VERSION"
    echo $NEW_VERSION
}

# Build Docker images
build_docker_images() {
    log "Building Docker images..."
    
    # Build frontend
    docker build -t eduai-frontend:latest ./frontend
    
    # Build backend (if needed)
    if [ -d "backend" ]; then
        docker build -t eduai-backend:latest ./backend
    fi
    
    success "Docker images built"
}

# Deploy to Kubernetes
deploy_to_kubernetes() {
    log "Deploying to Kubernetes..."
    
    # Check if Minikube is running
    if ! minikube status | grep -q "Running"; then
        error "Minikube is not running. Please start Minikube first."
    fi
    
    # Set Docker environment
    eval $(minikube docker-env)
    
    # Deploy frontend
    kubectl apply -f k8s/frontend-deployment-fixed.yaml
    kubectl apply -f k8s/frontend-nodeport-fixed.yaml
    
    # Deploy backend
    kubectl apply -f k8s/backend-deployment-fixed.yaml
    kubectl apply -f k8s/backend-nodeport-fixed.yaml
    
    # Wait for pods to be ready
    log "Waiting for pods to be ready..."
    kubectl wait --for=condition=ready pod -l app=frontend -n $NAMESPACE --timeout=300s
    kubectl wait --for=condition=ready pod -l app=backend -n $NAMESPACE --timeout=300s
    
    success "Kubernetes deployment completed"
}

# Show access information
show_access_info() {
    log "Getting access information..."
    
    MINIKUBE_IP=$(minikube ip)
    CURRENT_VERSION=$(get_current_version)
    
    echo ""
    echo "==============================================="
    echo "  DEPLOYMENT COMPLETE"
    echo "==============================================="
    echo ""
    echo "📱 PLATFORM ACCESS:"
    echo "  Frontend:     http://$MINIKUBE_IP:30320"
    echo "  Backend:      http://$MINIKUBE_IP:30420"
    echo "  AI Chat:      http://$MINIKUBE_IP:30420/ai-chat"
    echo ""
    echo "🔄 AUTO VERSIONING:"
    echo "  Current Version: $CURRENT_VERSION"
    echo "  UI Auto-Refresh: Enabled"
    echo "  Cache Busting: Active"
    echo ""
    echo "🌐 LOCAL ACCESS:"
    echo "  Use port forwarding: ./simple-port-forward.sh"
    echo "  Frontend: http://localhost:3200"
    echo "  Backend:  http://localhost:4200"
    echo ""
    echo "📊 MONITORING:"
    echo "  Grafana:      http://$MINIKUBE_IP:30004"
    echo "  Prometheus:   http://$MINIKUBE_IP:30930"
    echo ""
    echo "==============================================="
}

# Main deployment function
main() {
    case "${1:-full}" in
        version)
            get_current_version
            ;;
        update-version)
            update_version
            ;;
        build)
            build_frontend
            ;;
        deploy)
            deploy_to_kubernetes
            ;;
        full)
            log "Starting full deployment with auto versioning..."
            build_frontend
            build_docker_images
            deploy_to_kubernetes
            show_access_info
            ;;
        access)
            show_access_info
            ;;
        *)
            echo "Usage: $0 [version|update-version|build|deploy|full|access]"
            echo "  version       - Show current version"
            echo "  update-version - Update version with timestamp"
            echo "  build         - Build frontend with versioning"
            echo "  deploy        - Deploy to Kubernetes"
            echo "  full          - Complete deployment pipeline"
            echo "  access       - Show access information"
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"
