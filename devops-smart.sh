#!/bin/bash

set -euo pipefail

# =============================================================================
# 🧠 AI SMART LEARNING PLATFORM - INTELLIGENT DEVOPS
# =============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
DOMAIN="ailearn.duckdns.org"
TUNNEL_CONFIG_DIR="$HOME/.cloudflared"
NAMESPACE="eduai"
MODE=""
FAST_MODE_TIMEOUT=60
FULL_MODE_TIMEOUT=300

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --fast)
            MODE="FAST"
            shift
            ;;
        --full)
            MODE="FULL"
            shift
            ;;
        *)
            echo "Usage: $0 [--fast|--full]"
            exit 1
            ;;
    esac
done

# Logging functions
log_info() { echo -e "${BLUE}ℹ️  INFO: $1${NC}"; }
log_success() { echo -e "${GREEN}✅ SUCCESS: $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  WARNING: $1${NC}"; }
log_error() { echo -e "${RED}❌ ERROR: $1${NC}"; }
log_mode() { echo -e "${CYAN}🎯 MODE: $1${NC}"; }
log_skip() { echo -e "${YELLOW}⏭️  SKIP: $1${NC}"; }

# Advanced retry with exponential backoff
retry() {
    local retries=$1
    shift
    local command="$*"
    local count=0
    local backoff=1
    
    until $command; do
        exit_code=$?
        count=$((count + 1))
        if [ $count -lt $retries ]; then
            log_warning "Command failed (attempt $count/$retries). Retrying in ${backoff}s..."
            sleep $backoff
            backoff=$((backoff * 2))
        else
            log_error "Command failed after $retries attempts"
            return $exit_code
        fi
    done
}

# =============================================================================
# 🧠 INTELLIGENT MODE SELECTION
# =============================================================================
select_mode() {
    log_info "Detecting environment and selecting optimal mode..."
    
    # Check if any Minikube profile is running
    local running_profile=""
    if minikube profile list 2>/dev/null | grep -q "Running"; then
        running_profile=$(minikube profile list 2>/dev/null | grep "Running" | awk '{print $1}' | head -1)
        log_info "Found running Minikube profile: $running_profile"
        
        if [ "$MODE" = "FULL" ]; then
            log_mode "FULL (forced)"
            return 0
        else
            log_mode "FAST"
            return 1
        fi
    else
        log_mode "FULL"
        return 0
    fi
}

# =============================================================================
# 🐳 SMART RESOURCE DETECTION
# =============================================================================
detect_resources() {
    log_info "Auto-detecting system resources..."
    
    # CPU detection
    local cpu_cores=$(nproc)
    local cpu_target=$((cpu_cores / 2))
    if [ $cpu_target -lt 2 ]; then cpu_target=2; fi
    if [ $cpu_target -gt 4 ]; then cpu_target=4; fi
    
    # RAM detection
    local total_ram_mb=$(free -m | awk '/^Mem:/{print $2}')
    local ram_target=$((total_ram_mb / 2))
    if [ $ram_target -lt 2048 ]; then ram_target=2048; fi
    if [ $ram_target -gt 6144 ]; then ram_target=6144; fi
    
    echo "CPU_CORES=$cpu_cores"
    echo "CPU_TARGET=$cpu_target"
    echo "RAM_TOTAL=${total_ram_mb}MB"
    echo "RAM_TARGET=${ram_target}MB"
    
    # Export for use by other functions
    export CPU_TARGET=$cpu_target
    export RAM_TARGET=$ram_target
}

# =============================================================================
# 🐳 SMART DOCKER BUILD
# =============================================================================
smart_docker_build() {
    log_info "Smart Docker build analysis..."
    
    eval $(minikube docker-env)
    
    # Frontend build analysis
    local frontend_changed=false
    if [ -d "frontend" ]; then
        local current_checksum=$(find frontend -type f -exec sha1sum {} \; | sha1sum | cut -d' ' -f1)
        local checksum_file=".frontend-checksum"
        
        if [ -f "$checksum_file" ]; then
            local old_checksum=$(cat "$checksum_file")
            if [ "$current_checksum" != "$old_checksum" ]; then
                log_info "Frontend changes detected"
                echo "$current_checksum" > "$checksum_file"
                frontend_changed=true
            else
                log_skip "Frontend unchanged (skipping build)"
            fi
        else
            log_info "First-time frontend build"
            echo "$current_checksum" > "$checksum_file"
            frontend_changed=true
        fi
    else
        log_warning "Frontend directory not found, using nginx"
        frontend_changed=true
    fi
    
    # Backend build analysis
    local backend_changed=false
    if [ -d "backend" ]; then
        local current_checksum=$(find backend -type f -exec sha1sum {} \; | sha1sum | cut -d' ' -f1)
        local checksum_file=".backend-checksum"
        
        if [ -f "$checksum_file" ]; then
            local old_checksum=$(cat "$checksum_file")
            if [ "$current_checksum" != "$old_checksum" ]; then
                log_info "Backend changes detected"
                echo "$current_checksum" > "$checksum_file"
                backend_changed=true
            else
                log_skip "Backend unchanged (skipping build)"
            fi
        else
            log_info "First-time backend build"
            echo "$current_checksum" > "$checksum_file"
            backend_changed=true
        fi
    else
        log_warning "Backend directory not found, using nginx"
        backend_changed=true
    fi
    
    # Parallel builds if needed
    if [ "$frontend_changed" = true ] || [ "$backend_changed" = true ]; then
        log_info "Starting parallel Docker builds..."
        
        if [ "$frontend_changed" = true ]; then
            (
                if [ -d "frontend" ]; then
                    docker build -t eduai-frontend:latest ./frontend
                    log_success "Frontend image built"
                else
                    docker pull nginx:alpine
                    docker tag nginx:alpine eduai-frontend:latest
                    log_success "Frontend image (nginx) built"
                fi
            ) &
            local frontend_pid=$!
        fi
        
        if [ "$backend_changed" = true ]; then
            (
                if [ -d "backend" ]; then
                    docker build -t eduai-backend:latest ./backend
                    log_success "Backend image built"
                else
                    docker pull nginx:alpine
                    docker tag nginx:alpine eduai-backend:latest
                    log_success "Backend image (nginx) built"
                fi
            ) &
            local backend_pid=$!
        fi
        
        # Wait for builds
        if [ -n "${frontend_pid:-}" ]; then wait $frontend_pid; fi
        if [ -n "${backend_pid:-}" ]; then wait $backend_pid; fi
        
        log_success "All Docker builds completed"
    else
        log_skip "All images up to date"
    fi
}

# =============================================================================
# ⚡ FAST MODE EXECUTION
# =============================================================================
fast_mode() {
    log_info "Executing FAST mode..."
    
    # Setup environment
    eval $(minikube docker-env)
    
    # Quick namespace creation
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # Apply core services with minimal waiting
    log_info "Applying core services..."
    kubectl apply -f k8s/frontend-deployment-new.yaml -n $NAMESPACE
    kubectl apply -f k8s/backend-deployment-new.yaml -n $NAMESPACE
    
    # Smart waiting with short timeout
    log_info "Waiting for deployments (FAST mode)..."
    kubectl wait --for=condition=Available deployment/frontend -n $NAMESPACE --timeout=${FAST_MODE_TIMEOUT}s || true
    kubectl wait --for=condition=Available deployment/backend -n $NAMESPACE --timeout=${FAST_MODE_TIMEOUT}s || true
    
    # Self-healing
    heal_pods
    
    log_success "FAST mode completed"
}

# =============================================================================
# 🔥 FULL MODE EXECUTION
# =============================================================================
full_mode() {
    log_info "Executing FULL mode..."
    
    # Resource detection and setup
    detect_resources
    
    # Detect existing Kubernetes version
    local k8s_version=""
    local running_profile=""
    
    # Get running profile
    if minikube profile list 2>/dev/null | grep -q "Running"; then
        running_profile=$(minikube profile list 2>/dev/null | grep "Running" | awk '{print $1}' | head -1)
        log_info "Using running profile: $running_profile"
        
        # Try to get version from kubectl first
        if kubectl version --short >/dev/null 2>&1; then
            k8s_version=$(kubectl version --short 2>/dev/null | grep "Server Version" | awk '{print $3}' | sed 's/v//' || echo "")
        fi
        
        # Fallback to minikube kubectl if regular kubectl fails
        if [ -z "$k8s_version" ]; then
            k8s_version=$(minikube kubectl -- version --short 2>/dev/null | grep "Server Version" | awk '{print $3}' | sed 's/v//' || echo "")
        fi
        
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
    
    # Start Minikube only if not running
    if [ -n "$running_profile" ]; then
        log_info "Minikube profile '$running_profile' already running, skipping start"
        # Set docker env for existing cluster
        eval $(minikube docker-env)
    else
        # Start Minikube with detected resources and version
        log_info "Starting Minikube with optimal resources..."
        retry 3 minikube start \
            --driver=docker \
            --cpus=$CPU_TARGET \
            --memory=$RAM_TARGET \
            --kubernetes-version=$target_version
        
        eval $(minikube docker-env)
    fi
    
    retry 5 kubectl wait --for=condition=Ready nodes --all --timeout=${FULL_MODE_TIMEOUT}s
    
    # Smart Docker build
    smart_docker_build
    
    # Deploy Kubernetes
    log_info "Deploying Kubernetes resources..."
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -f k8s/frontend-deployment-new.yaml -n $NAMESPACE
    kubectl apply -f k8s/backend-deployment-new.yaml -n $NAMESPACE
    
    # Wait for deployments
    log_info "Waiting for deployments (FULL mode)..."
    retry 10 kubectl wait --for=condition=Available deployment/frontend -n $NAMESPACE --timeout=${FULL_MODE_TIMEOUT}s
    retry 10 kubectl wait --for=condition=Available deployment/backend -n $NAMESPACE --timeout=${FULL_MODE_TIMEOUT}s
    
    # Smart Helm installs
    smart_helm_install
    
    # Setup tunnel
    setup_cloudflare_tunnel
    
    log_success "FULL mode completed"
}

# =============================================================================
# 🧠 SMART HELM INSTALL
# =============================================================================
smart_helm_install() {
    log_info "Smart Helm installation check..."
    
    # ArgoCD install check
    if helm list -n argocd 2>/dev/null | grep -q argocd; then
        log_skip "ArgoCD already installed"
    else
        log_info "Installing ArgoCD..."
        helm repo add argo https://argoproj.github.io/argo-helm
        helm repo update
        
        helm upgrade --install argocd argo/argo-cd \
            --namespace argocd \
            --create-namespace \
            --set server.service.type=NodePort \
            --set server.service.nodePorts.http=32434 \
            --wait
        
        retry 5 kubectl wait --for=condition=Ready pods -n argocd -l app.kubernetes.io/name=argocd-server --timeout=${FULL_MODE_TIMEOUT}s
        log_success "ArgoCD installed"
    fi
    
    # Grafana install check
    if helm list -n monitoring 2>/dev/null | grep -q grafana; then
        log_skip "Grafana already installed"
    else
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
        
        retry 5 kubectl wait --for=condition=Ready pods -n monitoring -l app.kubernetes.io/name=grafana --timeout=${FULL_MODE_TIMEOUT}s
        log_success "Grafana installed"
    fi
}

# =============================================================================
# 🔄 SELF-HEALING (IMPROVED)
# =============================================================================
heal_pods() {
    log_info "Running self-healing..."
    
    # Delete failed pods
    local failed_pods=$(kubectl get pods -n $NAMESPACE --field-selector=status.phase=Failed -o name 2>/dev/null || true)
    if [ -n "$failed_pods" ]; then
        echo "$failed_pods" | while read pod; do
            log_info "Deleting failed pod: $pod"
            kubectl delete "$pod" -n $NAMESPACE --grace-period=0 --force || true
        done
    fi
    
    # Restart CrashLoopBackOff pods
    local crashloop_pods=$(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[?status.reason=="CrashLoopBackOff"].metadata.name}' 2>/dev/null || true)
    if [ -n "$crashloop_pods" ]; then
        echo "$crashloop_pods" | tr ' ' '\n' | while read pod; do
            if [ -n "$pod" ]; then
                log_info "Restarting CrashLoopBackOff pod: $pod"
                kubectl delete pod "$pod" -n $NAMESPACE || true
            fi
        done
    fi
    
    # Restart unhealthy deployments
    kubectl get deployments -n $NAMESPACE -o name | while read deployment; do
        local ready=$(kubectl get "$deployment" -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        local desired=$(kubectl get "$deployment" -n $NAMESPACE -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
        
        if [ "$ready" != "$desired" ] || [ "$ready" = "0" ]; then
            log_info "Restarting unhealthy deployment: $deployment"
            kubectl rollout restart "$deployment" -n $NAMESPACE || true
        fi
    done
    
    log_success "Self-healing completed"
}

# =============================================================================
# 🌐 CLOUDFLARE TUNNEL (IMPROVED)
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
        log_warning "No tunnel credentials found"
        echo ""
        echo "🌐 To set up Cloudflare Tunnel:"
        echo "1. Go to Cloudflare Dashboard > Zero Trust > Networks > Tunnels"
        echo "2. Create tunnel and download credentials file"
        echo "3. Place credentials file in: $TUNNEL_CONFIG_DIR/<tunnel-id>.json"
        echo "4. Run: ./devops-smart.sh again"
        echo ""
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
    
    # Kill existing tunnel processes
    pkill -f "cloudflared tunnel run" || true
    
    # Start tunnel
    nohup cloudflared tunnel run --config "$TUNNEL_CONFIG_DIR/config.yml" > "$TUNNEL_CONFIG_DIR/tunnel.log" 2>&1 &
    local tunnel_pid=$!
    
    sleep 5
    if kill -0 $tunnel_pid 2>/dev/null; then
        echo $tunnel_pid > "$TUNNEL_CONFIG_DIR/tunnel.pid"
        log_success "Cloudflare Tunnel started (PID: $tunnel_pid)"
    else
        log_warning "Failed to start Cloudflare Tunnel"
        tail -10 "$TUNNEL_CONFIG_DIR/tunnel.log"
    fi
}

# =============================================================================
# 📊 SYSTEM VERIFICATION
# =============================================================================
verify_system() {
    log_info "Verifying system..."
    
    # Check Minikube
    if ! minikube status | grep -q "Running"; then
        log_error "Minikube not running"
        return 1
    fi
    
    # Check pods
    local pod_count=$(kubectl get pods -n $NAMESPACE --no-headers | wc -l)
    if [ $pod_count -eq 0 ]; then
        log_error "No pods running"
        return 1
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
# 📤 ACCESS URLS OUTPUT
# =============================================================================
output_access_info() {
    echo ""
    echo "🌐 ACCESS URLS:"
    echo "==============="
    
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
    
    echo ""
    echo "📊 SYSTEM STATUS:"
    echo "================"
    kubectl get pods -n $NAMESPACE
    echo ""
    kubectl get services -n $NAMESPACE
}

# =============================================================================
# 🚀 MAIN EXECUTION
# =============================================================================
main() {
    echo "🧠 AI Smart Learning Platform - INTELLIGENT DevOps"
    echo "=================================================="
    echo ""
    
    # Check required tools
    local tools=("docker" "kubectl" "minikube" "helm" "cloudflared")
    for tool in "${tools[@]}"; do
        if ! command -v $tool &> /dev/null; then
            log_error "$tool not found. Please install it first."
            exit 1
        fi
    done
    log_success "All tools available"
    
    # Select mode
    if select_mode; then
        full_mode
    else
        fast_mode
    fi
    
    # Verify system
    verify_system
    
    # Output access information
    output_access_info
    
    echo ""
    log_success "Intelligent deployment completed successfully!"
}

# Execute main function
main "$@"
