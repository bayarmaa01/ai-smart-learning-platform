#!/bin/bash

set -euo pipefail

# =============================================================================
# 🚀 AI SMART LEARNING PLATFORM - FULL DEPLOYMENT
# =============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
DOMAIN="ailearn.duckdns.org"
TUNNEL_CONFIG_DIR="$HOME/.cloudflared"
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
            exit $exit_code
        fi
    done
}

# =============================================================================
# SYSTEM SETUP
# =============================================================================
check_tools() {
    log_info "Checking required tools..."
    local tools=("docker" "kubectl" "minikube" "helm" "cloudflared")
    for tool in "${tools[@]}"; do
        if ! command -v $tool &> /dev/null; then
            log_error "$tool not found. Please install it first."
            exit 1
        fi
    done
    log_success "All tools available"
}

# =============================================================================
# MINIKUBE SETUP (IDEMPOTENT)
# =============================================================================
setup_minikube() {
    log_info "Setting up Minikube..."
    
    # Check if any cluster is running
    local current_context=$(kubectl config current-context 2>/dev/null || echo "")
    if [ -n "$current_context" ] && minikube status 2>/dev/null | grep -q "Running"; then
        log_success "Minikube already running (context: $current_context)"
        kubectl config use-context "$current_context"
    else
        # Detect existing Kubernetes version
        local k8s_version=""
        if minikube status 2>/dev/null | grep -q "Running"; then
            k8s_version=$(kubectl version --short 2>/dev/null | grep "Server Version" | awk '{print $3}' | sed 's/v//' || echo "")
            if [ -n "$k8s_version" ]; then
                log_info "Detected existing cluster version: v$k8s_version"
            fi
        fi
        
        # Use existing version or default to latest stable
        local target_version=""
        if [ -n "$k8s_version" ]; then
            target_version="v$k8s_version"
            log_info "Using existing Kubernetes version: $target_version"
        else
            target_version="v1.28.0"
            log_info "Using default Kubernetes version: $target_version"
        fi
        
        log_info "Starting Minikube with version: $target_version"
        # Try docker driver first, fallback to none
        retry 3 minikube start \
            --driver=docker \
            --cpus=2 \
            --memory=4096 \
            --kubernetes-version=$target_version || \
        minikube start \
            --driver=none \
            --cpus=2 \
            --memory=4096 \
            --kubernetes-version=$target_version
        log_success "Minikube started"
    fi
    
    eval $(minikube docker-env)
    retry 5 kubectl wait --for=condition=Ready nodes --all --timeout=300s
}

# =============================================================================
# DOCKER BUILD
# =============================================================================
build_images() {
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
}

# =============================================================================
# KUBERNETES DEPLOY
# =============================================================================
deploy_kubernetes() {
    log_info "Deploying Kubernetes resources..."
    
    # Create namespace
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # Apply core services first
    log_info "Deploying core services..."
    kubectl apply -f k8s/frontend-deployment-new.yaml -n $NAMESPACE
    kubectl apply -f k8s/backend-deployment-new.yaml -n $NAMESPACE
    
    # Apply other manifests (skip argocd-application for now)
    if [ -d "k8s" ]; then
        for yaml in k8s/*.yaml; do
            if [ -f "$yaml" ] && [[ "$yaml" != *"argocd-application"* ]] && [[ "$yaml" != *"-new.yaml"* ]]; then
                log_info "Applying $yaml"
                kubectl apply -f "$yaml" -n $NAMESPACE
            fi
        done
    fi
    
    # Wait for core deployments
    retry 10 kubectl wait --for=condition=Available deployment/frontend -n $NAMESPACE --timeout=300s
    retry 10 kubectl wait --for=condition=Available deployment/backend -n $NAMESPACE --timeout=300s
    
    log_success "Kubernetes deployment completed"
}

create_basic_deployments() {
    # Frontend
    kubectl apply -n $NAMESPACE -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: eduai-frontend:latest
        imagePullPolicy: Never
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
spec:
  selector:
    app: frontend
  type: NodePort
  ports:
  - port: 3000
    targetPort: 80
    nodePort: 30007
EOF

    # Backend
    kubectl apply -n $NAMESPACE -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: eduai-backend:latest
        imagePullPolicy: Never
        ports:
        - containerPort: 5000
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: backend
spec:
  selector:
    app: backend
  type: NodePort
  ports:
  - port: 5000
    targetPort: 5000
    nodePort: 30008
EOF
}

# =============================================================================
# SELF-HEALING (CRONJOB)
# =============================================================================
setup_self_healing() {
    log_info "Setting up self-healing..."
    
    kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: CronJob
metadata:
  name: self-healing
  namespace: $NAMESPACE
spec:
  schedule: "*/2 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
          - name: healer
            image: bitnami/kubectl:latest
            command:
            - /bin/sh
            - -c
            - |
              # Delete failed pods
              kubectl get pods -n $NAMESPACE --field-selector=status.phase=Failed -o name | while read pod; do
                echo "Deleting failed pod: \$pod"
                kubectl delete "\$pod" -n $NAMESPACE --grace-period=0 --force || true
              done
              
              # Restart unhealthy deployments
              kubectl get deployments -n $NAMESPACE -o name | while read deployment; do
                ready=\$(kubectl get "\$deployment" -n $NAMESPACE -o jsonpath='{.status.readyReplicas}')
                desired=\$(kubectl get "\$deployment" -n $NAMESPACE -o jsonpath='{.spec.replicas}')
                if [ "\$ready" != "\$desired" ]; then
                  echo "Restarting deployment: \$deployment"
                  kubectl rollout restart "\$deployment" -n $NAMESPACE || true
                fi
              done
EOF
    
    log_success "Self-healing configured"
}

# =============================================================================
# HELM INSTALLATIONS
# =============================================================================
install_argocd() {
    log_info "Installing ArgoCD..."
    
    # Install ArgoCD CRDs first
    log_info "Installing ArgoCD CRDs..."
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --namespace argocd || true
    
    helm repo add argo https://argoproj.github.io/argo-helm
    helm repo update
    
    helm upgrade --install argocd argo/argo-cd \
        --namespace argocd \
        --create-namespace \
        --set server.service.type=NodePort \
        --set server.service.nodePorts.http=32434 \
        --set crds.install=true \
        --wait
    
    retry 5 kubectl wait --for=condition=Ready pods -n argocd -l app.kubernetes.io/name=argocd-server --timeout=300s
    log_success "ArgoCD installed"
}

install_grafana() {
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
}

# =============================================================================
# CLOUDFLARE TUNNEL
# =============================================================================
setup_cloudflare_tunnel() {
    log_info "Setting up Cloudflare Tunnel..."
    
    mkdir -p "$TUNNEL_CONFIG_DIR"
    
    # Detect tunnel credentials
    local tunnel_id=""
    local tunnel_file=""
    
    for file in "$TUNNEL_CONFIG_DIR"/*.json; do
        if [ -f "$file" ]; then
            tunnel_id=$(basename "$file" .json)
            tunnel_file="$file"
            break
        fi
    done
    
    if [ -z "$tunnel_id" ]; then
        log_warning "No tunnel credentials found in $TUNNEL_CONFIG_DIR"
        echo ""
        echo "🌐 To set up Cloudflare Tunnel:"
        echo "1. Go to Cloudflare Dashboard > Zero Trust > Networks > Tunnels"
        echo "2. Create tunnel and download credentials file"
        echo "3. Place credentials file in: $TUNNEL_CONFIG_DIR/<tunnel-id>.json"
        echo "4. Run: ./devops.sh again"
        echo ""
        log_success "Deployment completed without Cloudflare Tunnel"
        return 0
    fi
    
    # Get Minikube IP
    local minikube_ip=$(minikube ip)
    
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
        log_error "Failed to start Cloudflare Tunnel"
        exit 1
    fi
}

# =============================================================================
# FINAL VERIFICATION
# =============================================================================
verify_system() {
    log_info "Verifying system..."
    
    # Check Minikube
    if ! minikube status | grep -q "Running"; then
        log_error "Minikube not running"
        exit 1
    fi
    
    # Check pods
    local pod_count=$(kubectl get pods -n $NAMESPACE --no-headers | wc -l)
    if [ $pod_count -eq 0 ]; then
        log_error "No pods running"
        exit 1
    fi
    
    # Check tunnel (optional)
    if [ -f "$TUNNEL_CONFIG_DIR/tunnel.pid" ] && kill -0 $(cat "$TUNNEL_CONFIG_DIR/tunnel.pid") 2>/dev/null; then
        log_success "Cloudflare Tunnel running"
    else
        log_warning "Cloudflare Tunnel not configured or not running"
    fi
    
    log_success "System verification passed"
}

# =============================================================================
# MAIN
# =============================================================================
main() {
    echo "🚀 AI Smart Learning Platform - Full Deployment"
    echo "==============================================="
    
    check_tools
    setup_minikube
    build_images
    deploy_kubernetes
    setup_self_healing
    install_argocd
    install_grafana
    setup_cloudflare_tunnel
    verify_system
    
    echo ""
    echo "🌐 Access URLs:"
    local minikube_ip=$(minikube ip)
    echo "Frontend: http://$minikube_ip:30007"
    echo "Backend:  http://$minikube_ip:30008"
    echo "ArgoCD:   http://$minikube_ip:32434"
    echo "Grafana:  http://$minikube_ip:31385"
    
    # Check if tunnel is configured
    if [ -f "$TUNNEL_CONFIG_DIR/config.yml" ]; then
        echo ""
        echo "🌐 External Domain: https://$DOMAIN"
    else
        echo ""
        echo "🌐 External Domain: Not configured (see instructions above)"
    fi
}

main "$@"
