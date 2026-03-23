#!/usr/bin/env bash

# ==========================================================
#  EDUAI - Cloudflare Tunnel DevOps Startup Script
# ==========================================================
# Features
# - Auto Minikube cluster setup
# - Cloudflare Tunnel installation and management
# - Production-grade monitoring stack
# - Zero-trust security access
# ==========================================================

set -euo pipefail

############################################
# CONFIGURATION
############################################

CLUSTER_NAME="eduai-cluster"
NAMESPACE="eduai"
MONITORING_NAMESPACE="monitoring"
DOMAIN="ailearn.duckdns.org"
APP_DOMAIN="app.ailearn.duckdns.org"
API_DOMAIN="api.ailearn.duckdns.org"
AI_DOMAIN="ai.ailearn.duckdns.org"
TUNNEL_ID="dbea55ba-3659-4dd7-ac66-67f900defbfd"
CLOUDFLARED_CONFIG_DIR="$HOME/.cloudflared"
CLOUDFLARED_LOG_DIR="/var/log/cloudflared"

MINIKUBE_CPUS=4
MINIKUBE_MEMORY=6144

############################################
# COLORS
############################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

############################################
# LOGGING
############################################

log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

fail() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

cmd() {
    echo -e "${CYAN}[CMD]${NC} $1"
}

show_banner() {
    echo -e "${CYAN}"
    cat << "EOF"
    ____        __          __   _                 
   / __ \____  / /_  ____ _ / /  (_)___  ____ _ 
  / /_/ / __ \/ __ \/ __ \`// /  / / __ \/ __ \`/
 / ____/ /_/ / / / /_/ // /__/ / / / / /_/ /  
/_/    \____/_/ /_/\__,_//____/_/ /_/ /_/\__,_/   
                                                   
    EDUAI - Cloudflare Tunnel DevOps Platform
    AI Smart Learning Platform SaaS
    Domain: $DOMAIN
    Access: Zero Trust via Cloudflare Tunnel
EOF
    echo -e "${NC}"
}

############################################
# CHECK DEPENDENCIES
############################################

check_dependencies() {
    log "Checking dependencies..."
    
    local missing=()
    
    for cmd in kubectl docker helm minikube curl wget; do
        if ! command -v $cmd &> /dev/null; then
            missing+=($cmd)
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        fail "Missing dependencies: ${missing[*]}"
    fi
    
    success "All dependencies available"
}

############################################
# INSTALL CLOUDFLARED
############################################

install_cloudflared() {
    step "Installing cloudflared..."
    
    if ! command -v cloudflared &> /dev/null; then
        log "Downloading cloudflared..."
        local arch="amd64"
        if [[ "$(uname -m)" == "arm64" ]]; then
            arch="arm64"
        fi
        
        wget -O cloudflared "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${arch}"
        chmod +x cloudflared
        sudo mv cloudflared /usr/local/bin/cloudflared
        
        success "cloudflared installed"
    else
        log "cloudflared already installed"
    fi
    
    # Create directories
    mkdir -p "$CLOUDFLARED_CONFIG_DIR"
    sudo mkdir -p "$CLOUDFLARED_LOG_DIR"
    sudo chown $USER:$USER "$CLOUDFLARED_LOG_DIR"
}

############################################
# CREATE CLOUDFLARED CONFIG
############################################

create_cloudflared_config() {
    step "Creating cloudflared configuration..."
    
    cat > "$CLOUDFLARED_CONFIG_DIR/config.yml" <<EOF
tunnel: $TUNNEL_ID
credentials-file: $CLOUDFLARED_CONFIG_DIR/credentials.json

ingress:
  - hostname: $APP_DOMAIN
    service: http://ingress-nginx-controller.ingress-nginx.svc.cluster.local:80
    originRequest:
      noTLSVerify: true
  - hostname: $API_DOMAIN
    service: http://ingress-nginx-controller.ingress-nginx.svc.cluster.local:80
    originRequest:
      noTLSVerify: true
  - hostname: $AI_DOMAIN
    service: http://ingress-nginx-controller.ingress-nginx.svc.cluster.local:80
    originRequest:
      noTLSVerify: true
  - service: http_status:404
EOF

    success "cloudflared configuration created"
}

############################################
# CREATE SYSTEMD SERVICE
############################################

create_systemd_service() {
    step "Creating cloudflared systemd service..."
    
    sudo tee /etc/systemd/system/cloudflared.service > /dev/null <<EOF
[Unit]
Description=cloudflared Tunnel Service
After=network.target

[Service]
Type=simple
User=$USER
ExecStart=/usr/local/bin/cloudflared tunnel --config $CLOUDFLARED_CONFIG_DIR/config.yml run
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=cloudflared

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable cloudflared

    success "cloudflared systemd service created"
}

############################################
# START CLOUDFLARED TUNNEL
############################################

start_cloudflared_tunnel() {
    step "Starting Cloudflare Tunnel..."
    
    # Check if tunnel is already running
    if sudo systemctl is-active --quiet cloudflared; then
        log "Cloudflare Tunnel is already running"
        return 0
    fi
    
    # Start the service
    sudo systemctl start cloudflared
    
    # Wait for tunnel to be active
    local retries=0
    local max_retries=30
    while [ $retries -lt $max_retries ]; do
        if sudo systemctl is-active --quiet cloudflared; then
            success "Cloudflare Tunnel started successfully"
            return 0
        fi
        
        log "Waiting for tunnel to start... ($((retries + 1))/$max_retries)"
        sleep 2
        ((retries++))
    done
    
    fail "Failed to start Cloudflare Tunnel"
}

############################################
# VERIFY TUNNEL HEALTH
############################################

verify_tunnel_health() {
    step "Verifying Cloudflare Tunnel health..."
    
    local retries=0
    local max_retries=60
    local health_check_interval=5
    
    while [ $retries -lt $max_retries ]; do
        if curl -s --max-time 10 "https://$APP_DOMAIN/health" > /dev/null 2>&1; then
            success "Cloudflare Tunnel is healthy and accessible"
            return 0
        fi
        
        log "Checking tunnel health... ($((retries + 1))/$max_retries)"
        sleep $health_check_interval
        ((retries++))
    done
    
    warn "Cloudflare Tunnel health check failed, but tunnel may still be starting"
    return 0
}

############################################
# START MINIKUBE CLUSTER
############################################

start_cluster() {
    step "Starting Minikube cluster..."
    
    if minikube status -p $CLUSTER_NAME &>/dev/null; then
        log "Cluster already exists, checking status..."
        if ! minikube status -p $CLUSTER_NAME | grep -q "Running"; then
            log "Starting existing cluster..."
            minikube start -p $CLUSTER_NAME
        fi
    else
        log "Creating new cluster..."
        minikube start \
            -p $CLUSTER_NAME \
            --cpus=$MINIKUBE_CPUS \
            --memory=$MINIKUBE_MEMORY \
            --disk-size=50g \
            --kubernetes-version=v1.28.0 \
            --driver=docker \
            --container-runtime=docker
    fi
    
    # Set kubectl context
    kubectl config use-context $CLUSTER_NAME
    
    # Enable required addons
    log "Enabling Minikube addons..."
    minikube addons enable ingress -p $CLUSTER_NAME
    minikube addons enable metrics-server -p $CLUSTER_NAME
    minikube addons enable dashboard -p $CLUSTER_NAME
    
    # Connect Docker to Minikube
    eval $(minikube -p $CLUSTER_NAME docker-env)
    
    success "Minikube cluster ready"
}

############################################
# CREATE NAMESPACES
############################################

create_namespaces() {
    step "Creating Kubernetes namespaces..."
    
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace $MONITORING_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace logging --dry-run=client -o yaml | kubectl apply -f -
    
    success "Namespaces created"
}

############################################
# INSTALL INGRESS CONTROLLER
############################################

install_ingress_controller() {
    step "Installing NGINX Ingress Controller..."
    
    # Install NGINX Ingress Controller
    if ! kubectl get namespace ingress-nginx &>/dev/null; then
        kubectl create namespace ingress-nginx
    fi
    
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
    
    # Wait for ingress controller
    log "Waiting for Ingress Controller to be ready..."
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=300s
    
    success "NGINX Ingress Controller installed"
}

############################################
# AUTO-RESTART MONITOR
############################################

monitor_tunnel_restart() {
    step "Starting tunnel auto-restart monitor..."
    
    # Create monitoring script
    cat > "$HOME/.cloudflared/monitor.sh" <<'EOF'
#!/bin/bash

TUNNEL_SERVICE="cloudflared"
LOG_DIR="/var/log/cloudflared"
HEALTH_URL="https://$APP_DOMAIN/health"
CHECK_INTERVAL=30
MAX_FAILURES=3

failure_count=0

while true; do
    if ! systemctl is-active --quiet $TUNNEL_SERVICE; then
        echo "$(date): Tunnel service is down, restarting..."
        sudo systemctl restart $TUNNEL_SERVICE
        failure_count=$((failure_count + 1))
    elif ! curl -s --max-time 10 "$HEALTH_URL" > /dev/null 2>&1; then
        echo "$(date): Health check failed, failure count: $failure_count"
        failure_count=$((failure_count + 1))
        
        if [ $failure_count -ge $MAX_FAILURES ]; then
            echo "$(date): Too many failures, restarting tunnel..."
            sudo systemctl restart $TUNNEL_SERVICE
            failure_count=0
        fi
    else
        failure_count=0
    fi
    
    sleep $CHECK_INTERVAL
done
EOF

    chmod +x "$HOME/.cloudflared/monitor.sh"
    
    # Create monitor service
    sudo tee /etc/systemd/system/cloudflared-monitor.service > /dev/null <<EOF
[Unit]
Description=cloudflared Tunnel Monitor Service
After=cloudflared.service

[Service]
Type=simple
User=$USER
ExecStart=$HOME/.cloudflared/monitor.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable cloudflared-monitor
    sudo systemctl start cloudflared-monitor
    
    success "Tunnel auto-restart monitor started"
}

############################################
# SHOW STATUS
############################################

show_status() {
    step "System Status"
    
    echo -e "\n${GREEN}🚀 EDUAI Cloudflare Tunnel Platform${NC}\n"
    
    echo -e "${CYAN}📊 Service Status:${NC}"
    echo -e "   🌐 Cloudflare Tunnel: $(sudo systemctl is-active cloudflared)"
    echo -e "   🔍 Tunnel Monitor:   $(sudo systemctl is-active cloudflared-monitor)"
    echo -e "   ☸️  Minikube:        $(minikube status -p $CLUSTER_NAME | head -1 | awk '{print $2}')"
    
    echo -e "\n${CYAN}🌐 Access URLs:${NC}"
    echo -e "   🌐 Frontend:     ${YELLOW}https://$APP_DOMAIN${NC}"
    echo -e "   🔧 Backend API:  ${YELLOW}https://$API_DOMAIN${NC}"
    echo -e "   🤖 AI Service:   ${YELLOW}https://$AI_DOMAIN${NC}"
    
    echo -e "\n${CYAN}🔍 Health Check:${NC}"
    echo -e "   curl -s https://$APP_DOMAIN/health"
    
    echo -e "\n${CYAN}📋 Management Commands:${NC}"
    echo -e "   📊 Tunnel Status:  sudo systemctl status cloudflared"
    echo -e "   📜 Tunnel Logs:    sudo journalctl -u cloudflared -f"
    echo -e "   🔄 Restart Tunnel: sudo systemctl restart cloudflared"
    echo -e "   📈 Minikube Status: minikube status -p $CLUSTER_NAME"
    
    echo -e "\n${CYAN}⚙️  Configuration:${NC}"
    echo -e "   📁 Config File:     $CLOUDFLARED_CONFIG_DIR/config.yml"
    echo -e "   📁 Log Directory:   $CLOUDFLARED_LOG_DIR"
    echo -e "   🏷️  Tunnel ID:      $TUNNEL_ID"
    echo -e "   🌐 Frontend URL:   $APP_DOMAIN"
    echo -e "   🔧 API URL:       $API_DOMAIN"
    echo -e "   🤖 AI URL:        $AI_DOMAIN"
}

############################################
# MAIN EXECUTION
############################################

main() {
    show_banner
    
    # Check if tunnel ID is configured
    if [ "$TUNNEL_ID" == "YOUR_TUNNEL_ID_HERE" ]; then
        fail "Please update TUNNEL_ID in the script with your actual Cloudflare Tunnel ID"
    fi
    
    check_dependencies
    install_cloudflared
    create_cloudflared_config
    create_systemd_service
    start_cluster
    create_namespaces
    install_ingress_controller
    start_cloudflared_tunnel
    verify_tunnel_health
    monitor_tunnel_restart
    show_status
    
    success "EDUAI Cloudflare Tunnel platform is ready!"
}

# Handle script interruption
trap 'warn "Script interrupted. Tunnel will continue running."' INT TERM

# Run main function
main "$@"
