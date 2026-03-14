#!/bin/bash

# Setup local Kubernetes cluster for AI Smart Learning Platform
# Supports Minikube and Kind

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_TYPE="kind"  # Change to "minikube" if preferred
CLUSTER_NAME="eduai-cluster"
NODE_COUNT="3"

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
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    
    # Check cluster tool
    if [ "$CLUSTER_TYPE" = "minikube" ]; then
        if ! command -v minikube &> /dev/null; then
            log_error "minikube is not installed. Please install minikube first."
            exit 1
        fi
    elif [ "$CLUSTER_TYPE" = "kind" ]; then
        if ! command -v kind &> /dev/null; then
            log_error "kind is not installed. Please install kind first."
            exit 1
        fi
    fi
    
    log_success "Prerequisites check passed"
}

setup_cluster() {
    log_info "Setting up $CLUSTER_TYPE cluster..."
    
    if [ "$CLUSTER_TYPE" = "minikube" ]; then
        setup_minikube
    elif [ "$CLUSTER_TYPE" = "kind" ]; then
        setup_kind
    fi
}

setup_minikube() {
    log_info "Creating Minikube cluster..."
    
    # Check if cluster already exists
    if minikube status | grep -q "Running"; then
        log_warning "Minikube cluster already exists. Deleting and recreating..."
        minikube delete
    fi
    
    # Create cluster with required resources
    minikube start \
        --name $CLUSTER_NAME \
        --nodes $NODE_COUNT \
        --cpus 4 \
        --memory 8192 \
        --disk-size 50g \
        --kubernetes-version v1.28.0 \
        --driver=docker
    
    # Enable required addons
    minikube addons enable ingress
    minikube addons enable metrics-server
    
    log_success "Minikube cluster created"
}

setup_kind() {
    log_info "Creating Kind cluster..."
    
    # Create Kind config
    cat > kind-config.yaml << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: $CLUSTER_NAME
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
- role: worker
  extraPortMappings:
  - containerPort: 80
    hostPort: 8080
    protocol: TCP
- role: worker
  extraPortMappings:
  - containerPort: 5000
    hostPort: 5000
    protocol: TCP
- role: worker
  extraPortMappings:
  - containerPort: 8000
    hostPort: 8000
    protocol: TCP
EOF
    
    # Delete existing cluster if it exists
    if kind get clusters | grep -q $CLUSTER_NAME; then
        log_warning "Kind cluster already exists. Deleting and recreating..."
        kind delete cluster --name $CLUSTER_NAME
    fi
    
    # Create cluster
    kind create cluster --config kind-config.yaml
    
    log_success "Kind cluster created"
}

install_ingress() {
    log_info "Installing NGINX Ingress Controller..."
    
    if [ "$CLUSTER_TYPE" = "kind" ]; then
        # For Kind, install NGINX Ingress
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
    else
        # For Minikube, ingress is already enabled
        log_info "NGINX Ingress already enabled in Minikube"
    fi
    
    # Wait for ingress controller
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=300s
    
    log_success "NGINX Ingress Controller installed"
}

install_cert_manager() {
    log_info "Installing cert-manager for TLS..."
    
    # Install cert-manager
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
    
    # Wait for cert-manager
    kubectl wait --for=condition=available deployment/cert-manager -n cert-manager --timeout=300s
    kubectl wait --for=condition=available deployment/cert-manager-cainjector -n cert-manager --timeout=300s
    kubectl wait --for=condition=available deployment/cert-manager-webhook -n cert-manager --timeout=300s
    
    log_success "cert-manager installed"
}

setup_helm() {
    log_info "Setting up Helm..."
    
    # Add Helm repositories
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add jetstack https://charts.jetstack.io
    helm repo update
    
    log_success "Helm repositories added"
}

setup_storage() {
    log_info "Setting up storage classes..."
    
    if [ "$CLUSTER_TYPE" = "kind" ]; then
        # Create storage class for Kind
        kubectl apply -f - << EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
provisioner: rancher.io/local-path
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
EOF
    else
        log_info "Using default storage class"
    fi
    
    log_success "Storage classes configured"
}

verify_cluster() {
    log_info "Verifying cluster setup..."
    
    # Check cluster nodes
    log_info "Cluster nodes:"
    kubectl get nodes
    
    # Check namespaces
    log_info "Namespaces:"
    kubectl get namespaces
    
    # Check ingress controller
    log_info "Ingress controller pods:"
    kubectl get pods -n ingress-nginx
    
    # Check cert-manager
    log_info "cert-manager pods:"
    kubectl get pods -n cert-manager
    
    log_success "Cluster verification completed"
}

get_access_info() {
    log_info "Getting cluster access information..."
    
    if [ "$CLUSTER_TYPE" = "minikube" ]; then
        log_info "Minikube access:"
        echo "Minikube IP: $(minikube ip)"
        echo "Dashboard: minikube dashboard"
    else
        log_info "Kind access:"
        echo "Cluster is running on localhost"
        echo "Use port-forwarding to access services:"
        echo "kubectl port-forward -n eduai svc/frontend-service 8080:8080"
    fi
    
    log_info "Use the following command to deploy the platform:"
    echo "./deploy-k8s.sh deploy"
}

cleanup() {
    log_warning "Cleaning up cluster..."
    
    if [ "$CLUSTER_TYPE" = "minikube" ]; then
        minikube delete
    elif [ "$CLUSTER_TYPE" = "kind" ]; then
        kind delete cluster --name $CLUSTER_NAME
    fi
    
    # Clean up config file
    rm -f kind-config.yaml
    
    log_success "Cluster cleanup completed"
}

show_help() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  setup      - Setup complete local cluster"
    echo "  cluster    - Setup cluster only"
    echo "  ingress    - Install ingress controller only"
    echo "  certmgr    - Install cert-manager only"
    echo "  helm       - Setup Helm repositories only"
    echo "  storage    - Setup storage classes only"
    echo "  verify     - Verify cluster setup"
    echo "  cleanup    - Delete cluster"
    echo "  help       - Show this help message"
    echo ""
    echo "Environment variables:"
    echo "  CLUSTER_TYPE - 'minikube' or 'kind' (default: kind)"
    echo "  CLUSTER_NAME - Cluster name (default: eduai-cluster)"
    echo "  NODE_COUNT   - Number of nodes (default: 3)"
    echo ""
    echo "Examples:"
    echo "  $0 setup           # Setup complete cluster"
    echo "  $0 cluster         # Setup cluster only"
    echo "  CLUSTER_TYPE=minikube $0 setup  # Use Minikube instead of Kind"
}

# Main script logic
case "${1:-setup}" in
    "setup")
        check_prerequisites
        setup_cluster
        install_ingress
        install_cert_manager
        setup_helm
        setup_storage
        verify_cluster
        get_access_info
        log_success "🎉 Local Kubernetes cluster setup completed!"
        ;;
    "cluster")
        check_prerequisites
        setup_cluster
        ;;
    "ingress")
        install_ingress
        ;;
    "certmgr")
        install_cert_manager
        ;;
    "helm")
        setup_helm
        ;;
    "storage")
        setup_storage
        ;;
    "verify")
        verify_cluster
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
