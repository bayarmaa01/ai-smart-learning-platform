#!/bin/bash

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
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
            log_warning "Command failed (attempt $count/$retries). Retrying in 5 seconds..."
            sleep 5
        else
            log_error "Command failed after $retries attempts"
            return $exit_code
        fi
    done
}

echo "🚀 CONTINUE DEPLOYMENT"
echo "===================="

# Step 1: Build Docker images
log_info "Building Docker images..."
eval $(minikube docker-env)

# Frontend
if [ -d "frontend" ]; then
    docker build -t eduai-frontend:latest ./frontend
    log_success "Frontend image built"
else
    docker pull nginx:alpine
    docker tag nginx:alpine eduai-frontend:latest
    log_warning "Using nginx for frontend (directory not found)"
fi

# Backend
if [ -d "backend" ]; then
    docker build -t eduai-backend:latest ./backend
    log_success "Backend image built"
else
    docker pull nginx:alpine
    docker tag nginx:alpine eduai-backend:latest
    log_warning "Using nginx for backend (directory not found)"
fi

# Step 2: Deploy Kubernetes
log_info "Deploying Kubernetes resources..."

# Create namespace
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Apply core services
kubectl apply -f k8s/frontend-deployment-new.yaml -n $NAMESPACE
kubectl apply -f k8s/backend-deployment-new.yaml -n $NAMESPACE

# Wait for deployments
retry 10 kubectl wait --for=condition=Available deployment/frontend -n $NAMESPACE --timeout=300s
retry 10 kubectl wait --for=condition=Available deployment/backend -n $NAMESPACE --timeout=300s

log_success "Kubernetes deployment completed"

# Step 3: Install ArgoCD
log_info "Installing ArgoCD..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm upgrade --install argocd argo/argo-cd \
    --namespace argocd \
    --create-namespace \
    --set server.service.type=NodePort \
    --set server.service.nodePorts.http=32434 \
    --wait

retry 5 kubectl wait --for=condition=Ready pods -n argocd -l app.kubernetes.io/name=argocd-server --timeout=300s
log_success "ArgoCD installed"

# Step 4: Install Grafana
log_info "Installing Grafana..."
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm upgrade --install grafana grafana/grafana \
    --namespace monitoring \
    --create-namespace \
    --set service.type=NodePort \
    --set service.nodePort=31385 \
    --set adminPassword='admin123' \
    --set persistence.enabled=false \
    --wait

retry 5 kubectl wait --for=condition=Ready pods -n monitoring -l app.kubernetes.io/name=grafana --timeout=300s
log_success "Grafana installed"

# Step 5: Setup Cloudflare Tunnel (optional)
log_info "Setting up Cloudflare Tunnel..."
TUNNEL_CONFIG_DIR="$HOME/.cloudflared"
DOMAIN="ailearn.duckdns.org"

mkdir -p "$TUNNEL_CONFIG_DIR"

# Check for tunnel credentials
tunnel_id=""
tunnel_file=""

for file in "$TUNNEL_CONFIG_DIR"/*.json; do
    if [ -f "$file" ]; then
        tunnel_id=$(basename "$file" .json)
        tunnel_file="$file"
        break
    fi
done

if [ -z "$tunnel_id" ]; then
    log_warning "No tunnel credentials found. Skipping Cloudflare Tunnel setup."
    echo ""
    echo "🌐 To set up Cloudflare Tunnel:"
    echo "1. Go to Cloudflare Dashboard > Zero Trust > Networks > Tunnels"
    echo "2. Create tunnel and download credentials file"
    echo "3. Place credentials file in: $TUNNEL_CONFIG_DIR/<tunnel-id>.json"
    echo "4. Run: ./setup-tunnel.sh"
else
    # Get Minikube IP
    local minikube_ip=$(minikube ip -p eduai-cluster)
    
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
        log_warning "Failed to start Cloudflare Tunnel"
    fi
fi

# Step 6: Show status
log_info "Deployment completed! Status:"
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
echo "📊 Access URLs:"
local minikube_ip=$(minikube ip -p eduai-cluster)
echo "Frontend: http://$minikube_ip:30007"
echo "Backend:  http://$minikube_ip:30008"
echo "ArgoCD:   http://$minikube_ip:32434"
echo "Grafana:  http://$minikube_ip:31385"

if [ -n "$tunnel_id" ]; then
    echo ""
    echo "🌐 External Domain: https://$DOMAIN"
fi

echo ""
log_success "Continue deployment completed!"
