#!/bin/bash

set -euo pipefail

# =============================================================================
# 🚀 AI SMART LEARNING PLATFORM - FULL AUTOMATED DEPLOYMENT
# =============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOMAIN="ailearn.duckdns.org"
TUNNEL_CONFIG_DIR="$HOME/.cloudflared"
FRONTEND_NODEPORT="30007"
BACKEND_NODEPORT="30008"

# Logging functions
log_info() { echo -e "${BLUE}ℹ️  INFO: $1${NC}"; }
log_success() { echo -e "${GREEN}✅ SUCCESS: $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  WARNING: $1${NC}"; }
log_error() { echo -e "${RED}❌ ERROR: $1${NC}"; }

# Retry function for stability
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
# STEP 1: SYSTEM VALIDATION
# =============================================================================
validate_system() {
    log_info "Validating system requirements..."
    
    # Check CPU cores
    local cpu_cores=$(nproc)
    if [ $cpu_cores -lt 2 ]; then
        log_error "CPU cores insufficient: $cpu_cores (minimum: 2)"
        exit 1
    fi
    log_success "CPU cores: $cpu_cores ✓"
    
    # Check RAM
    local total_ram=$(free -g | awk '/^Mem:/{print $2}')
    if [ $total_ram -lt 4 ]; then
        log_error "RAM insufficient: ${total_ram}GB (minimum: 4GB)"
        exit 1
    fi
    log_success "RAM: ${total_ram}GB ✓"
    
    # Check required tools
    local tools=("docker" "kubectl" "minikube" "helm" "cloudflared")
    for tool in "${tools[@]}"; do
        if ! command -v $tool &> /dev/null; then
            log_error "$tool not found. Please install it first."
            exit 1
        fi
        log_success "$tool ✓"
    done
    
    log_success "System validation completed"
}

# =============================================================================
# STEP 2: MINIKUBE SETUP
# =============================================================================
setup_minikube() {
    log_info "Setting up Minikube cluster..."
    
    # Clean up existing cluster
    log_info "Cleaning up existing cluster..."
    minikube stop -p eduai-cluster 2>/dev/null || true
    minikube delete -p eduai-cluster 2>/dev/null || true
    
    # Start new cluster
    log_info "Starting Minikube cluster..."
    retry 3 minikube start -p eduai-cluster \
        --driver=docker \
        --cpus=2 \
        --memory=4096 \
        --kubernetes-version=v1.28.0 \
        --wait=all
    
    # Set context and enable docker env
    kubectl config use-context eduai-cluster
    eval $(minikube docker-env)
    
    # Wait for nodes to be ready
    retry 5 kubectl wait --for=condition=Ready nodes --all --timeout=300s
    
    log_success "Minikube cluster ready"
}

# =============================================================================
# STEP 3: BUILD DOCKER IMAGES
# =============================================================================
build_images() {
    log_info "Building Docker images..."
    
    eval $(minikube docker-env)
    
    # Build frontend image
    log_info "Building frontend image..."
    if [ -d "frontend" ]; then
        docker build -t eduai-frontend:latest ./frontend
        log_success "Frontend image built"
    else
        log_warning "Frontend directory not found, using nginx"
        docker pull nginx:alpine
        docker tag nginx:alpine eduai-frontend:latest
    fi
    
    # Build backend image
    log_info "Building backend image..."
    if [ -d "backend" ]; then
        docker build -t eduai-backend:latest ./backend
        log_success "Backend image built"
    else
        log_warning "Backend directory not found, using nginx"
        docker pull nginx:alpine
        docker tag nginx:alpine eduai-backend:latest
    fi
    
    log_success "All images built successfully"
}

# =============================================================================
# STEP 4: KUBERNETES DEPLOY
# =============================================================================
deploy_kubernetes() {
    log_info "Deploying Kubernetes resources..."
    
    # Create namespace
    kubectl create namespace eduai --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy frontend
    log_info "Deploying frontend..."
    kubectl apply -n eduai -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  labels:
    app: frontend
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
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
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
    nodePort: $FRONTEND_NODEPORT
EOF
    
    # Deploy backend
    log_info "Deploying backend..."
    kubectl apply -n eduai -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  labels:
    app: backend
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
        readinessProbe:
          httpGet:
            path: /api/health
            port: 5000
          initialDelaySeconds: 10
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /api/health
            port: 5000
          initialDelaySeconds: 30
          periodSeconds: 10
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
    nodePort: $BACKEND_NODEPORT
EOF
    
    # Wait for deployments to be ready
    retry 10 kubectl wait --for=condition=Available deployment/frontend -n eduai --timeout=300s
    retry 10 kubectl wait --for=condition=Available deployment/backend -n eduai --timeout=300s
    
    log_success "Kubernetes deployment completed"
}

# =============================================================================
# STEP 5: CLOUDFLARE TUNNEL SETUP
# =============================================================================
setup_cloudflare_tunnel() {
    log_info "Setting up Cloudflare Tunnel..."
    
    # Create config directory
    mkdir -p "$TUNNEL_CONFIG_DIR"
    
    # Auto-detect or use existing tunnel
    local tunnel_id=""
    local tunnel_file=""
    
    # Look for existing tunnel credentials
    for file in "$TUNNEL_CONFIG_DIR"/*.json; do
        if [ -f "$file" ]; then
            tunnel_id=$(basename "$file" .json)
            tunnel_file="$file"
            log_info "Found existing tunnel: $tunnel_id"
            break
        fi
    done
    
    # If no tunnel found, create a new one
    if [ -z "$tunnel_id" ]; then
        log_warning "No existing tunnel found. Please create a tunnel manually:"
        echo "1. Go to Cloudflare Dashboard > Zero Trust > Networks > Tunnels"
        echo "2. Click 'Create tunnel' > 'Cloudflared tunnel'"
        echo "3. Save the tunnel ID and download credentials file"
        echo "4. Place credentials file in: $TUNNEL_CONFIG_DIR/<tunnel-id>.json"
        log_error "Tunnel setup required. Please run script again after creating tunnel."
        exit 1
    fi
    
    # Generate tunnel configuration
    log_info "Generating tunnel configuration..."
    cat > "$TUNNEL_CONFIG_DIR/config.yml" <<EOF
tunnel: $tunnel_id
credentials-file: $tunnel_file

ingress:
  - hostname: $DOMAIN
    service: http://localhost:$FRONTEND_NODEPORT
  - service: http_status:404
EOF
    
    log_success "Tunnel configuration created: $TUNNEL_CONFIG_DIR/config.yml"
    
    # Start tunnel
    log_info "Starting Cloudflare Tunnel..."
    
    # Kill existing tunnel processes
    pkill -f "cloudflared tunnel run" || true
    
    # Start tunnel in background
    nohup cloudflared tunnel run --config "$TUNNEL_CONFIG_DIR/config.yml" > "$TUNNEL_CONFIG_DIR/tunnel.log" 2>&1 &
    local tunnel_pid=$!
    
    # Wait for tunnel to start
    sleep 5
    
    # Check if tunnel is running
    if kill -0 $tunnel_pid 2>/dev/null; then
        log_success "Cloudflare Tunnel started (PID: $tunnel_pid)"
        echo $tunnel_pid > "$TUNNEL_CONFIG_DIR/tunnel.pid"
    else
        log_error "Failed to start Cloudflare Tunnel"
        tail -20 "$TUNNEL_CONFIG_DIR/tunnel.log"
        exit 1
    fi
}

# =============================================================================
# STEP 6: SELF-HEALING
# =============================================================================
setup_self_healing() {
    log_info "Setting up self-healing..."
    
    # Create a self-healing script as a ConfigMap
    kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: self-healing-script
  namespace: eduai
data:
  heal.sh: |
    #!/bin/bash
    # Auto-heal failed pods
    kubectl get pods -n eduai --field-selector=status.phase=Failed -o name | while read pod; do
        echo "Deleting failed pod: \$pod"
        kubectl delete "\$pod" -n eduai
    done
    
    # Restart deployments with failed pods
    kubectl get deployments -n eduai -o name | while read deployment; do
        ready=\$(kubectl get "\$deployment" -n eduai -o jsonpath='{.status.readyReplicas}')
        desired=\$(kubectl get "\$deployment" -n eduai -o jsonpath='{.spec.replicas}')
        if [ "\$ready" != "\$desired" ]; then
            echo "Restarting deployment: \$deployment"
            kubectl rollout restart "\$deployment" -n eduai
        fi
    done
    
    # Restart tunnel if stopped
    if [ ! -f "$TUNNEL_CONFIG_DIR/tunnel.pid" ] || ! kill -0 \$(cat "$TUNNEL_CONFIG_DIR/tunnel.pid") 2>/dev/null; then
        echo "Restarting Cloudflare Tunnel"
        nohup cloudflared tunnel run --config "$TUNNEL_CONFIG_DIR/config.yml" > "$TUNNEL_CONFIG_DIR/tunnel.log" 2>&1 &
        echo \$! > "$TUNNEL_CONFIG_DIR/tunnel.pid"
    fi
EOF
    
    log_success "Self-healing configured"
}

# =============================================================================
# STEP 7: VERIFY SYSTEM
# =============================================================================
verify_system() {
    log_info "Verifying system deployment..."
    
    # Check Minikube
    if ! minikube status -p eduai-cluster | grep -q "Running"; then
        log_error "Minikube is not running"
        exit 1
    fi
    
    # Check pods
    local frontend_pods=$(kubectl get pods -n eduai -l app=frontend --no-headers | wc -l)
    local backend_pods=$(kubectl get pods -n eduai -l app=backend --no-headers | wc -l)
    
    if [ $frontend_pods -eq 0 ] || [ $backend_pods -eq 0 ]; then
        log_error "Pods are not running"
        exit 1
    fi
    
    # Check tunnel
    if [ ! -f "$TUNNEL_CONFIG_DIR/tunnel.pid" ] || ! kill -0 $(cat "$TUNNEL_CONFIG_DIR/tunnel.pid") 2>/dev/null; then
        log_error "Cloudflare Tunnel is not running"
        exit 1
    fi
    
    log_success "System verification passed"
}

# =============================================================================
# STEP 8: OUTPUT ACCESS INFORMATION
# =============================================================================
output_access_info() {
    log_info "Generating access information..."
    
    echo ""
    echo "=== 🚀 SYSTEM READY ==="
    echo ""
    
    echo "🌐 Domain:"
    echo "https://$DOMAIN"
    echo ""
    
    echo "Status:"
    echo "✅ Tunnel: RUNNING"
    echo "✅ Pods: RUNNING"
    echo "✅ Minikube: RUNNING"
    echo ""
    
    echo "📱 Local Access:"
    local minikube_ip=$(minikube ip -p eduai-cluster)
    echo "Frontend: http://$minikube_ip:$FRONTEND_NODEPORT"
    echo "Backend:  http://$minikube_ip:$BACKEND_NODEPORT"
    echo ""
    
    echo "🔍 System Status:"
    echo "==============="
    kubectl get pods -n eduai
    echo ""
    
    echo "🌐 Services:"
    echo "==========="
    kubectl get svc -n eduai
    echo ""
    
    echo "📋 Management Commands:"
    echo "======================"
    echo "Check tunnel logs: tail -f $TUNNEL_CONFIG_DIR/tunnel.log"
    echo "Restart tunnel: pkill -f cloudflared && ./run.sh"
    echo "Check pods: kubectl get pods -n eduai"
    echo "Stop system: pkill -f cloudflared && minikube stop -p eduai-cluster"
    echo ""
    
    log_success "Deployment completed successfully!"
    log_info "Open https://$DOMAIN in your browser"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================
main() {
    echo "🚀 AI Smart Learning Platform - Full Automated Deployment"
    echo "========================================================="
    echo ""
    
    validate_system
    setup_minikube
    build_images
    deploy_kubernetes
    setup_cloudflare_tunnel
    setup_self_healing
    verify_system
    output_access_info
}

# Execute main function
main "$@"
