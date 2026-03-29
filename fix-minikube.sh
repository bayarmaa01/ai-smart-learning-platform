#!/bin/bash

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  INFO: $1${NC}"; }
log_success() { echo -e "${GREEN}✅ SUCCESS: $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  WARNING: $1${NC}"; }
log_error() { echo -e "${RED}❌ ERROR: $1${NC}"; }

echo "🔧 MINIKUBE FIX SCRIPT"
echo "===================="

# Step 1: Complete cleanup
log_info "Step 1: Complete cleanup..."
minikube stop -p eduai-cluster 2>/dev/null || true
minikube delete -p eduai-cluster 2>/dev/null || true
docker system prune -f 2>/dev/null || true
log_success "Cleanup completed"

# Step 2: Reset Docker environment
log_info "Step 2: Reset Docker environment..."
docker container prune -f 2>/dev/null || true
docker volume prune -f 2>/dev/null || true
log_success "Docker reset completed"

# Step 3: Start fresh Minikube with stable config
log_info "Step 3: Starting fresh Minikube..."
minikube start -p eduai-cluster \
    --driver=docker \
    --cpus=2 \
    --memory=4096 \
    --kubernetes-version=v1.28.0 \
    --force \
    --wait=all

log_success "Minikube started"

# Step 4: Verify cluster
log_info "Step 4: Verifying cluster..."
kubectl config use-context eduai-cluster

# Wait for nodes to be ready
for i in {1..30}; do
    if kubectl get nodes | grep -q "Ready"; then
        log_success "Cluster is ready"
        break
    fi
    echo "Waiting for cluster to be ready... ($i/30)"
    sleep 10
done

# Step 5: Test basic functionality
log_info "Step 5: Testing basic functionality..."
kubectl get nodes
kubectl get pods -A

log_success "Minikube fix completed!"
echo ""
echo "🚀 You can now run: ./devops.sh"
