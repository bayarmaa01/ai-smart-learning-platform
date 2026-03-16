#!/bin/bash

# AI Smart Learning Platform - Kubernetes Deployment Script
# This script deploys the complete platform to Kubernetes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="eduai"
MONITORING_NAMESPACE="monitoring"
DOMAIN="eduai.yourdomain.com"
REGISTRY="bayarmaa"
DOCKER_HUB_USERNAME="bayarmaa"

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    
    # Check if helm is installed
    if ! command -v helm &> /dev/null; then
        log_error "helm is not installed. Please install helm first."
        exit 1
    fi
    
    # Check if cluster is accessible
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

setup_namespaces() {
    log_info "Setting up namespaces..."
    
    # Create main namespace
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # Create monitoring namespace
    kubectl create namespace $MONITORING_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    log_success "Namespaces created"
}

deploy_infrastructure() {
    log_info "Deploying infrastructure components (PostgreSQL, Redis)..."
    
    # Apply secrets first
    kubectl apply -f k8s/eduai-secrets.yaml
    
    # Apply ConfigMaps
    kubectl apply -f k8s/configmap.yaml
    kubectl apply -f k8s/monitoring-config.yaml
    
    # Deploy PostgreSQL
    log_info "Deploying PostgreSQL..."
    kubectl apply -f k8s/postgres-statefulset.yaml
    
    # Deploy Redis
    log_info "Deploying Redis..."
    kubectl apply -f k8s/redis-deployment.yaml
    
    # Wait for PostgreSQL to be ready
    log_info "Waiting for PostgreSQL to be ready..."
    kubectl wait --for=condition=ready pod -l app=postgres -n $NAMESPACE --timeout=300s
    
    # Wait for Redis to be ready
    log_info "Waiting for Redis to be ready..."
    kubectl wait --for=condition=ready pod -l app=redis -n $NAMESPACE --timeout=300s
    
    log_success "Infrastructure deployed successfully"
}

deploy_applications() {
    log_info "Deploying application services..."
    
    # Deploy Backend
    log_info "Deploying Backend..."
    kubectl apply -f k8s/service-accounts.yaml
    kubectl apply -f k8s/backend-deployment.yaml
    
    # Deploy AI Service
    log_info "Deploying AI Service..."
    kubectl apply -f k8s/ai-service-deployment.yaml
    
    # Deploy Frontend
    log_info "Deploying Frontend..."
    kubectl apply -f k8s/frontend-deployment.yaml
    
    # Wait for all services to be ready
    log_info "Waiting for Backend to be ready..."
    kubectl wait --for=condition=available deployment/backend -n $NAMESPACE --timeout=300s
    
    log_info "Waiting for AI Service to be ready..."
    kubectl wait --for=condition=available deployment/ai-service -n $NAMESPACE --timeout=300s
    
    log_info "Waiting for Frontend to be ready..."
    kubectl wait --for=condition=available deployment/frontend -n $NAMESPACE --timeout=300s
    
    log_success "Application services deployed successfully"
}

setup_networking() {
    log_info "Setting up networking..."
    
    # Apply network policies
    kubectl apply -f k8s/network-policy.yaml
    
    # Apply Ingress
    kubectl apply -f k8s/ingress.yaml
    
    log_success "Networking configured"
}

deploy_monitoring() {
    log_info "Deploying monitoring stack..."
    
    # Deploy Prometheus, Grafana, AlertManager
    kubectl apply -f k8s/monitoring-stack.yaml
    
    # Wait for monitoring stack
    log_info "Waiting for Prometheus to be ready..."
    kubectl wait --for=condition=available deployment/prometheus -n $MONITORING_NAMESPACE --timeout=300s
    
    log_info "Waiting for Grafana to be ready..."
    kubectl wait --for=condition=available deployment/grafana -n $MONITORING_NAMESPACE --timeout=300s
    
    log_success "Monitoring stack deployed"
}

setup_argocd() {
    log_info "Setting up ArgoCD..."
    
    # Apply ArgoCD application
    kubectl apply -f k8s/argocd-application.yaml
    
    log_success "ArgoCD configured"
}

verify_deployment() {
    log_info "Verifying deployment..."
    
    # Check all pods
    log_info "Checking pod status..."
    kubectl get pods -n $NAMESPACE
    
    # Check services
    log_info "Checking services..."
    kubectl get services -n $NAMESPACE
    
    # Check ingress
    log_info "Checking ingress..."
    kubectl get ingress -n $NAMESPACE
    
    # Get external IP or hostname
    log_info "Getting access information..."
    
    # For local clusters (minikube/kind)
    if kubectl cluster-info | grep -q "minikube\|kind"; then
        log_info "For local cluster, use port-forward:"
        echo "kubectl port-forward -n $NAMESPACE svc/frontend-service 8080:8080"
        echo "kubectl port-forward -n $NAMESPACE svc/backend-service 5000:5000"
        echo "kubectl port-forward -n $MONITORING_NAMESPACE svc/grafana 3000:3000"
        echo "kubectl port-forward -n $MONITORING_NAMESPACE svc/prometheus 9090:9090"
    else
        log_info "Access URLs:"
        echo "Frontend: https://$DOMAIN"
        echo "Backend API: https://$DOMAIN/api"
        echo "AI Service: https://$DOMAIN/ai"
        echo "Grafana: http://$(kubectl get svc grafana -n $MONITORING_NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):3000"
        echo "Prometheus: http://$(kubectl get svc prometheus -n $MONITORING_NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):9090"
    fi
    
    log_success "Deployment verification completed"
}

cleanup() {
    log_warning "Cleaning up deployment..."
    
    # Delete all resources
    kubectl delete namespace $NAMESPACE --ignore-not-found=true
    kubectl delete namespace $MONITORING_NAMESPACE --ignore-not-found=true
    
    log_success "Cleanup completed"
}

show_help() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  deploy     - Deploy the complete platform"
    echo "  infra      - Deploy only infrastructure (PostgreSQL, Redis)"
    echo "  apps       - Deploy only applications (Backend, AI, Frontend)"
    echo "  monitoring - Deploy only monitoring stack"
    echo "  verify     - Verify deployment status"
    echo "  cleanup    - Delete all deployed resources"
    echo "  help       - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 deploy          # Deploy everything"
    echo "  $0 infra           # Deploy infrastructure only"
    echo "  $0 apps            # Deploy applications only"
    echo "  $0 verify          # Check deployment status"
}

# Main script logic
case "${1:-deploy}" in
    "deploy")
        check_prerequisites
        setup_namespaces
        deploy_infrastructure
        deploy_applications
        setup_networking
        deploy_monitoring
        setup_argocd
        verify_deployment
        log_success "🎉 AI Smart Learning Platform deployed successfully!"
        ;;
    "infra")
        check_prerequisites
        setup_namespaces
        deploy_infrastructure
        verify_deployment
        ;;
    "apps")
        check_prerequisites
        deploy_applications
        verify_deployment
        ;;
    "monitoring")
        check_prerequisites
        setup_namespaces
        deploy_monitoring
        verify_deployment
        ;;
    "verify")
        verify_deployment
        ;;
    "cleanup")
        cleanup
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
