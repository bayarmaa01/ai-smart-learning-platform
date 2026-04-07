#!/bin/bash

# =============================================================================
# Domain Access Script for AI Smart Learning Platform
# =============================================================================
# This script helps configure and test domain access via Cloudflare tunnel
# =============================================================================

set -e

# Configuration
DOMAIN="ailearn.duckdns.org"
NAMESPACE="eduai"
TUNNEL_NAME="eduai-tunnel"

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

# Check if cloudflared is installed
check_cloudflared() {
    if ! command -v cloudflared >/dev/null 2>&1; then
        log_error "cloudflared not found"
        log_info "Install cloudflared:"
        log_info "  # Download and install"
        log_info "  wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.tar.gz"
        log_info "  tar xzf cloudflared-linux-amd64.tar.gz"
        log_info "  sudo mv cloudflared /usr/local/bin/"
        log_info "  # Or on Windows/Mac, download from: https://github.com/cloudflare/cloudflared/releases/latest"
        exit 1
    fi
}

# Setup Cloudflare tunnel
setup_tunnel() {
    log_info "Setting up Cloudflare tunnel for $DOMAIN..."
    
    # Check if authenticated
    if [ ! -f "$HOME/.cloudflared/cert.pem" ]; then
        log_info "Please authenticate Cloudflare Tunnel..."
        cloudflared tunnel login
    fi
    
    # Create tunnel if not exists
    local tunnel_id=$(cloudflared tunnel list 2>/dev/null | grep "$TUNNEL_NAME" | awk '{print $2}' || echo "")
    
    if [ -z "$tunnel_id" ]; then
        log_info "Creating new tunnel: $TUNNEL_NAME"
        local tunnel_output=$(cloudflared tunnel create "$TUNNEL_NAME" 2>&1)
        tunnel_id=$(echo "$tunnel_output" | grep "Created tunnel" | awk '{print $3}' || echo "")
        if [ -z "$tunnel_id" ]; then
            tunnel_id=$(echo "$tunnel_output" | tail -1 | awk '{print $NF}' || echo "")
        fi
        if [ -z "$tunnel_id" ]; then
            log_error "Failed to create tunnel: $tunnel_output"
            exit 1
        fi
        log_success "Created tunnel with ID: $tunnel_id"
    else
        log_success "Using existing tunnel: $TUNNEL_NAME"
    fi
    
    # Create config directory
    mkdir -p "$HOME/.cloudflared"
    
    # Create tunnel config
    cat > "$HOME/.cloudflared/config.yml" <<EOF
tunnel: $tunnel_id
credentials-file: $HOME/.cloudflared/$tunnel_id.json

ingress:
  - hostname: $DOMAIN
    service: http://localhost:3000
  - service: http_status:404
EOF
    
    # Setup DNS record
    log_info "Setting up DNS record for $DOMAIN..."
    if ! cloudflared tunnel route dns "$TUNNEL_NAME" "$DOMAIN" >/dev/null 2>&1; then
        log_info "Creating DNS record for $DOMAIN..."
        cloudflared tunnel route dns "$TUNNEL_NAME" "$DOMAIN" || {
            log_warning "DNS record already exists or failed to create"
            log_info "The tunnel will still work, but DNS may need manual configuration"
        }
    else
        log_success "DNS record already exists for $DOMAIN"
    fi
    
    log_success "Tunnel configuration completed"
}

# Start tunnel
start_tunnel() {
    log_info "Starting Cloudflare tunnel..."
    
    # Stop existing tunnel
    stop_tunnel
    
    # Start tunnel in background
    nohup cloudflared tunnel run "$TUNNEL_NAME" > "$HOME/.cloudflared/tunnel.log" 2>&1 &
    local tunnel_pid=$!
    echo $tunnel_pid > "$HOME/.cloudflared/tunnel.pid"
    
    # Wait for tunnel to start
    local max_wait=30
    local wait_count=0
    while [ $wait_count -lt $max_wait ]; do
        if kill -0 $tunnel_pid 2>/dev/null; then
            log_success "Cloudflare Tunnel started successfully"
            break
        fi
        wait_count=$((wait_count + 2))
        sleep 2
    done
    
    if [ $wait_count -ge $max_wait ]; then
        log_warning "Tunnel taking longer than expected, but continuing..."
    fi
    
    log_info "Tunnel logs: tail -f $HOME/.cloudflared/tunnel.log"
}

# Stop tunnel
stop_tunnel() {
    log_info "Stopping Cloudflare tunnel..."
    
    if [ -f "$HOME/.cloudflared/tunnel.pid" ]; then
        local tunnel_pid=$(cat "$HOME/.cloudflared/tunnel.pid")
        if kill -0 $tunnel_pid 2>/dev/null; then
            kill $tunnel_pid 2>/dev/null || true
            log_success "Stopped tunnel (PID: $tunnel_pid)"
        fi
        rm -f "$HOME/.cloudflared/tunnel.pid"
    fi
    
    # Kill any existing cloudflared processes
    pkill -f "cloudflared tunnel run" 2>/dev/null || true
}

# Test domain connectivity
test_domain() {
    log_info "Testing domain connectivity..."
    
    echo "Testing $DOMAIN..."
    if curl -s "https://$DOMAIN" >/dev/null; then
        log_success "Domain $DOMAIN is accessible"
    else
        log_warning "Domain $DOMAIN not accessible (may still be starting)"
    fi
    
    echo ""
    echo "Testing subdomains..."
    
    # Test API endpoint
    if curl -s "https://$DOMAIN/api/v1/health" >/dev/null; then
        log_success "API accessible at https://$DOMAIN/api/v1/health"
    else
        log_warning "API not yet accessible"
    fi
    
    echo ""
    echo "DNS Information:"
    echo "================"
    nslookup "$DOMAIN" 2>/dev/null || dig "$DOMAIN" 2>/dev/null || echo "DNS lookup failed"
}

# Show domain status
show_status() {
    echo "Domain Access Status:"
    echo "===================="
    echo "Domain: $DOMAIN"
    echo "Tunnel: $TUNNEL_NAME"
    
    if [ -f "$HOME/.cloudflared/tunnel.pid" ]; then
        local tunnel_pid=$(cat "$HOME/.cloudflared/tunnel.pid")
        if kill -0 $tunnel_pid 2>/dev/null; then
            echo "Tunnel: RUNNING (PID: $tunnel_pid)"
        else
            echo "Tunnel: STOPPED"
            rm -f "$HOME/.cloudflared/tunnel.pid"
        fi
    else
        echo "Tunnel: STOPPED"
    fi
    
    echo ""
    test_domain
}

# Show access URLs
show_urls() {
    echo ""
    echo "ACCESS URLS:"
    echo "============"
    echo "Public Domain: https://$DOMAIN"
    echo ""
    echo "If port forwarding is active:"
    echo "Frontend:     http://localhost:3000"
    echo "Backend:      http://localhost:5000"
    echo "API Health:   http://localhost:5000/health"
    echo ""
    echo "API Endpoints (via domain):"
    echo "Frontend:     https://$DOMAIN"
    echo "Backend API: https://$DOMAIN/api/v1"
    echo "Health:      https://$DOMAIN/api/v1/health"
}

# Main function
main() {
    case "${1:-status}" in
        "setup")
            check_cloudflared
            setup_tunnel
            ;;
        "start")
            check_cloudflared
            start_tunnel
            show_urls
            ;;
        "stop")
            stop_tunnel
            ;;
        "restart")
            stop_tunnel
            sleep 2
            main start
            ;;
        "test")
            test_domain
            ;;
        "status")
            show_status
            ;;
        "urls")
            show_urls
            ;;
        "help"|"-h"|"--help")
            echo "Usage: $0 [setup|start|stop|restart|test|status|urls|help]"
            echo ""
            echo "Commands:"
            echo "  setup   - Setup Cloudflare tunnel and DNS"
            echo "  start   - Start Cloudflare tunnel"
            echo "  stop    - Stop Cloudflare tunnel"
            echo "  restart - Restart Cloudflare tunnel"
            echo "  test    - Test domain connectivity"
            echo "  status  - Show current status"
            echo "  urls    - Show access URLs"
            echo "  help    - Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 setup    # Initial setup"
            echo "  $0 start    # Start tunnel"
            echo "  $0 test     # Test connectivity"
            echo ""
            echo "Note: Make sure port forwarding is running first:"
            echo "  ./port-forward.sh start"
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Handle script interruption
trap 'log_warning "Script interrupted"; stop_tunnel; exit 1' INT TERM

# Run main function
main "$@"
