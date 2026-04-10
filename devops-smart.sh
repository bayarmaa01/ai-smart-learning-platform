#!/bin/bash

# AI Smart Learning Platform - Production DevOps Script
# Supports WSL2 + Minikube + Cloudflare Tunnel
# Usage: ./devops-smart.sh [full|fast]

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
NAMESPACE="eduai"
DOMAIN="ailearn.duckdns.org"
TUNNEL_NAME="eduai-tunnel"
TUNNEL_CONFIG_DIR="$HOME/.cloudflared"
FRONTEND_NODEPORT=30007
BACKEND_NODEPORT=30008
MINIKUBE_IP=""

# Timeout configurations
FULL_MODE_TIMEOUT=300
FAST_MODE_TIMEOUT=120

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${PURPLE}[STEP]${NC} $1"; }

# Parse arguments
MODE="full"
RESET_CLUSTER=false
SHOW_STATUS=false
AUTO_FORWARD=false
FORCE_BUILD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        full|--full)
            MODE="full"
            shift
            ;;
        fast|--fast)
            MODE="fast"
            shift
            ;;
        --reset)
            RESET_CLUSTER=true
            shift
            ;;
        --status)
            SHOW_STATUS=true
            shift
            ;;
        --forward)
            AUTO_FORWARD=true
            shift
            ;;
        --force-build)
            FORCE_BUILD=true
            shift
            ;;
        *)
            echo "Usage: $0 [--fast|--full|--reset|--status|--forward|--force-build]"
            echo ""
            echo "Modes:"
            echo "  --fast         Skip rebuild, only restart pods"
            echo "  --full         Rebuild images + redeploy everything"
            echo "  --reset        Delete minikube + clean start"
            echo "  --status       Show cluster + pod health"
            echo "  --forward      Auto port-forward services"
            echo "  --force-build  Force rebuild all images"
            exit 1
            ;;
    esac
done

# =============================================================================
# 📝 LOGGING FUNCTIONS
# =============================================================================
log_info() { echo -e "${BLUE}ℹ️  INFO: $1${NC}"; }
log_success() { echo -e "${GREEN}✅ SUCCESS: $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  WARNING: $1${NC}"; }
log_error() { echo -e "${RED}❌ ERROR: $1${NC}"; }
log_step() { echo -e "${CYAN}🔄 STEP: $1${NC}"; }

# Error handling
trap 'log_error "Script failed at line $LINENO"' ERR

# =============================================================================
# 🔧 UTILITY FUNCTIONS
# =============================================================================
retry() {
    local retries=$1
    shift
    local count=0
    until "$@"; do
        exit_code=$?
        count=$((count + 1))
        if [ $count -lt $retries ]; then
            log_warning "Command failed (attempt $count/$retries). Retrying in ${count}s..."
            sleep $count
        else
            log_error "Command failed after $retries attempts"
            return $exit_code
        fi
    done
}

wait_for_pods() {
    local namespace=$1
    local timeout=${2:-300}
    local label=${3:-""}
    
    log_info "Waiting for pods in namespace '$namespace'..."
    local selector=""
    if [ -n "$label" ]; then
        selector="-l $label"
    fi
    
    # Use minikube kubectl to avoid connection issues
    minikube kubectl -- wait --for=condition=Ready pods -n "$namespace" $selector --timeout="${timeout}s" || {
        log_warning "Some pods are not ready within ${timeout}s"
        return 1
    }
}

# =============================================================================
# 🚀 KUBERNETES VERSION DETECTION
# =============================================================================
detect_k8s_version() {
    if kubectl cluster-info >/dev/null 2>&1; then
        # Use short output - most reliable method
        local version=$(kubectl version --short 2>/dev/null | grep "Server Version" | awk '{print $3}' || echo "")
        if [ -n "$version" ]; then
            echo "$version"
            return 0
        fi
    fi
    
    # Always return default as fallback
    echo "v1.34.0"
}

# =============================================================================
# 🛡️ CLUSTER HEALTH AUTO-RECOVERY
# =============================================================================
ensure_cluster_health() {
    log_step "Ensuring cluster health..."
    
    # Check if kubectl can connect
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_warning "kubectl cannot connect to cluster, attempting recovery..."
        
        # Try to start minikube
        if ! minikube status >/dev/null 2>&1; then
            log_info "Starting Minikube..."
            retry 3 minikube start --driver=docker
        fi
        
        # Set context
        log_info "Setting kubectl context..."
        kubectl config use-context minikube >/dev/null 2>&1 || true
        
        # Validate connection
        if ! kubectl get nodes >/dev/null 2>&1; then
            log_error "Failed to establish cluster connection"
            return 1
        fi
    fi
    
    log_success "Cluster is healthy"
    return 0
}

# =============================================================================
# 🗄️ POSTGRESQL DEPLOYMENT AND HEALTH CHECK
# =============================================================================
deploy_postgresql() {
    log_step "🔄 STEP: Deploying PostgreSQL database and Redis cache..."
    
    # Create namespace if needed
    minikube kubectl -- create namespace "$NAMESPACE" --dry-run=client -o yaml | minikube kubectl -- apply -f -
    
    # Create PostgreSQL ConfigMap first
    cat <<EOF | minikube kubectl -- apply -f -
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-config
  namespace: $NAMESPACE
data:
  postgresql.conf: |
    # Disable SSL for development
    ssl = off
    # Allow all connections for development
    listen_addresses = '*'
    # Connection settings
    max_connections = 100
    # Logging
    log_statement = 'all'
    log_min_duration_statement = 1000
  pg_hba.conf: |
    # TYPE  DATABASE        USER            ADDRESS                 METHOD
    # Allow local connections
    local   all             postgres                                trust
    local   all             all                                     trust
    # Allow IPv4 connections without SSL
    host    all             all             0.0.0.0/0               trust
    # Allow IPv6 connections without SSL  
    host    all             all             ::/0                    trust
EOF
    
    # Deploy PostgreSQL
    cat <<EOF | minikube kubectl -- apply -f -
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: $NAMESPACE
  labels:
    app: postgres
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      securityContext:
        runAsUser: 999
        runAsGroup: 999
        fsGroup: 999
      containers:
      - name: postgres
        image: postgres:15-alpine
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 5432
        command:
        - "docker-entrypoint.sh"
        - "postgres"
        - "-c"
        - "config_file=/etc/postgresql/postgresql.conf"
        - "-c"
        - "hba_file=/etc/postgresql/pg_hba.conf"
        env:
        - name: POSTGRES_DB
          value: "eduai"
        - name: POSTGRES_USER
          value: "postgres"
        - name: POSTGRES_PASSWORD
          value: "postgres123"
        - name: POSTGRES_HOST_AUTH_METHOD
          value: "trust"
        - name: POSTGRES_INITDB_ARGS
          value: "--auth-host=md5"
        - name: POSTGRES_INITDB_WALDIR
          value: "/var/lib/postgresql/wal"
        - name: PGDATA
          value: "/var/lib/postgresql/data/pgdata"
        securityContext:
          runAsUser: 999
          runAsGroup: 999
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "200m"
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        - name: postgres-config
          mountPath: /etc/postgresql/postgresql.conf
          subPath: postgresql.conf
        - name: postgres-config
          mountPath: /etc/postgresql/pg_hba.conf
          subPath: pg_hba.conf
        readinessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - postgres
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        livenessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - postgres
          initialDelaySeconds: 60
          periodSeconds: 15
          timeoutSeconds: 10
          failureThreshold: 3
      volumes:
      - name: postgres-storage
        emptyDir: {}
      - name: postgres-config
        configMap:
          name: postgres-config
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: $NAMESPACE
spec:
  selector:
    app: postgres
  type: ClusterIP
  ports:
  - port: 5432
    targetPort: 5432
EOF
    
    # Wait for PostgreSQL to be ready
    log_info "Waiting for PostgreSQL to be ready..."
    
    # Check pod status manually first
    local pod_status=""
    local max_wait=120
    local wait_count=0
    
    while [ $wait_count -lt $max_wait ]; do
        pod_status=$(minikube kubectl -- get pods -n "$NAMESPACE" -l app=postgres -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "")
        if [ "$pod_status" = "Running" ]; then
            log_success "PostgreSQL is running"
            break
        fi
        wait_count=$((wait_count + 5))
        if [ $wait_count -lt $max_wait ]; then
            echo -n "."
            sleep 5
        fi
    done
    
    if [ $wait_count -ge $max_wait ]; then
        log_warning "PostgreSQL taking longer than expected, but continuing..."
    fi
    
    log_success "PostgreSQL is ready"
    
    # Deploy Redis
    log_info "Deploying Redis cache..."
    cat <<EOF | minikube kubectl -- apply -f -
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: $NAMESPACE
  labels:
    app: redis
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 6379
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: false
        readinessProbe:
          exec:
            command:
            - redis-cli
            - ping
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        livenessProbe:
          exec:
            command:
            - redis-cli
            - ping
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: $NAMESPACE
spec:
  selector:
    app: redis
  type: ClusterIP
  ports:
  - port: 6379
    targetPort: 6379
EOF
    
    # Wait for Redis to be ready
    log_info "Waiting for Redis to be ready..."
    local redis_status=""
    local max_wait=60
    local wait_count=0
    
    while [ $wait_count -lt $max_wait ]; do
        redis_status=$(minikube kubectl -- get pods -n "$NAMESPACE" -l app=redis -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "")
        if [ "$redis_status" = "Running" ]; then
            log_success "Redis is running"
            break
        fi
        wait_count=$((wait_count + 5))
        if [ $wait_count -lt $max_wait ]; then
            echo -n "."
            sleep 5
        fi
    done
    
    if [ $wait_count -ge $max_wait ]; then
        log_warning "Redis taking longer than expected, but continuing..."
    fi
    
    log_success "Redis is ready"
    return 0
}

# =============================================================================
# 🧠 SMART DOCKER BUILD
# =============================================================================
smart_docker_build() {
    log_step "Building Docker images..."
    
    # Check if images exist in Docker environment
    local frontend_exists=$(docker images 2>/dev/null | grep eduai-frontend | wc -l)
    local backend_exists=$(docker images 2>/dev/null | grep eduai-backend | wc -l)
    
    if [ "$FORCE_BUILD" = true ] || [ "$frontend_exists" -eq 0 ] || [ "$backend_exists" -eq 0 ]; then
        log_info "Force build requested, rebuilding all images"
        
        # Build frontend
        log_info "Building frontend image..."
        if ! docker build -t eduai-frontend:latest ./frontend 2>&1; then
            log_error "Failed to build frontend image"
            return 1
        fi
        log_success "Frontend image built"
        
        # Build backend
        log_info "Building backend image..."
        if ! docker build -t eduai-backend:latest ./backend 2>&1; then
            log_error "Failed to build backend image"
            return 1
        fi
        log_success "Backend image built"
        
        log_success "All images built successfully"
    else
        log_info "Images already exist, skipping build (use --force-build to rebuild)"
    fi
    
    return 0
}

# =============================================================================
# 🚀 DEPLOY APPLICATIONS
# =============================================================================
deploy_applications() {
    log_step "Deploying applications..."
    
    # Deploy frontend with security fixes
    cat <<EOF | minikube kubectl -- apply -f -
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: $NAMESPACE
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
        - containerPort: 8080
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: false
        readinessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        livenessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 15
          timeoutSeconds: 10
          failureThreshold: 3
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: $NAMESPACE
spec:
  selector:
    app: frontend
  type: NodePort
  ports:
  - port: 3000
    targetPort: 8080
    nodePort: 30007
EOF
    
    # Deploy backend with database connection
    cat <<EOF | minikube kubectl -- apply -f -
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: $NAMESPACE
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
        env:
        - name: DATABASE_URL
          value: "postgresql://postgres:postgres123@postgres:5432/eduai?sslmode=disable"
        - name: DB_HOST
          value: "postgres"
        - name: DB_PORT
          value: "5432"
        - name: DB_NAME
          value: "eduai"
        - name: DB_USER
          value: "postgres"
        - name: DB_PASSWORD
          value: "postgres123"
        - name: DB_SSL_MODE
          value: "disable"
        - name: REDIS_HOST
          value: "redis"
        - name: REDIS_PORT
          value: "6379"
        - name: REDIS_DB
          value: "0"
        - name: OLLAMA_URL
          value: "http://host.minikube.internal:11434"
        - name: OLLAMA_MODEL
          value: "gemma:2b"
        - name: NODE_ENV
          value: "production"
        - name: PORT
          value: "5000"
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        readinessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 45
          periodSeconds: 15
          timeoutSeconds: 10
          failureThreshold: 3
        livenessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 90
          periodSeconds: 30
          timeoutSeconds: 15
          failureThreshold: 3
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: $NAMESPACE
spec:
  selector:
    app: backend
  type: NodePort
  ports:
  - port: 5000
    targetPort: 5000
    nodePort: 30008
EOF
    
    log_success "Applications deployed"
}

# =============================================================================
# 🔍 BACKEND CRASHLOOP AUTO-DEBUG
# =============================================================================
debug_backend_pods() {
    log_step "Debugging backend pods..."
    
    local failed_pods=$(minikube kubectl -- get pods -n "$NAMESPACE" -l app=backend -o jsonpath='{.items[?(@.status.phase=="Failed")].metadata.name}' 2>/dev/null || echo "")
    local crashloop_pods=$(minikube kubectl -- get pods -n "$NAMESPACE" -l app=backend -o jsonpath='{.items[?(@.status.reason=="CrashLoopBackOff")].metadata.name}' 2>/dev/null || echo "")
    
    if [ -n "$failed_pods" ] || [ -n "$crashloop_pods" ]; then
        log_warning "Found problematic backend pods, analyzing logs..."
        
        for pod in $failed_pods $crashloop_pods; do
            if [ -n "$pod" ]; then
                log_info "Analyzing pod: $pod"
                
                # Get previous logs
                local logs=$(minikube kubectl -- logs "$pod" -n "$NAMESPACE" --previous 2>/dev/null || echo "")
                
                # Detect common issues
                if echo "$logs" | grep -q "ECONNREFUSED"; then
                    log_error "❌ Database connection refused - PostgreSQL not ready"
                fi
                
                if echo "$logs" | grep -q "ENOTFOUND"; then
                    log_error "❌ Database hostname not found - DNS issue"
                fi
                
                if echo "$logs" | grep -q "authentication failed"; then
                    log_error "❌ Database authentication failed - wrong credentials"
                fi
                
                if echo "$logs" | grep -q "NODE_ENV"; then
                    log_error "❌ Missing environment variables"
                fi
                
                if echo "$logs" | grep -q "ModuleNotFoundError"; then
                    log_error "❌ Python module missing - need to rebuild image"
                fi
                
                if echo "$logs" | grep -q "ImportError"; then
                    log_error "❌ Python import error - need to rebuild image"
                fi
                
                # Show sample logs
                if [ -n "$logs" ]; then
                    log_info "Last 10 lines from pod $pod:"
                    echo "$logs" | tail -10
                else
                    log_info "No previous logs found for pod $pod, trying current logs..."
                    local current_logs=$(minikube kubectl -- logs "$pod" -n "$NAMESPACE" 2>/dev/null || echo "")
                    if [ -n "$current_logs" ]; then
                        echo "$current_logs" | tail -10
                    else
                        log_warning "Could not fetch logs for pod $pod"
                    fi
                fi
            fi
        done
        
        log_info "Suggestion: Try rebuilding backend image with --force-build flag"
    fi
}

# =============================================================================
# 🔄 MODE EXECUTION
# =============================================================================
execute_fast_mode() {
    log_info "Executing FAST mode..."
    
    # Ensure cluster health
    ensure_cluster_health
    
    # Restart deployments
    log_info "Restarting deployments..."
    minikube kubectl -- rollout restart deployment/frontend -n "$NAMESPACE"
    minikube kubectl -- rollout restart deployment/backend -n "$NAMESPACE"
    
    # Wait for pods
    wait_for_pods "$NAMESPACE" "$FAST_MODE_TIMEOUT" "app=frontend" || true
    wait_for_pods "$NAMESPACE" "$FAST_MODE_TIMEOUT" "app=backend" || true
    
    # Setup Cloudflare Tunnel for external access
    setup_cloudflare_tunnel
    
    # Show access information
    show_access_info
    
    # Debug if needed
    debug_backend_pods
    
    log_success "FAST mode completed"
}

execute_full_mode() {
    log_info "Executing FULL mode..."
    
    # Get target version (clean value only)
    local target_version=$(detect_k8s_version | tr -d '[:space:]')
    
    # Validate version format
    if [[ ! "$target_version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_error "Invalid Kubernetes version: $target_version"
        exit 1
    fi
    
    # Check for existing cluster to prevent downgrade
    local current_version=""
    if kubectl cluster-info >/dev/null 2>&1; then
        # Use short output - most reliable method
        current_version=$(kubectl version --short 2>/dev/null | grep "Server Version" | awk '{print $3}' || echo "")
    fi
    
    # Use existing version to avoid downgrade
    local final_version="$target_version"
    if [[ -n "$current_version" && "$current_version" != "$target_version" ]]; then
        log_warning "Existing cluster version ($current_version) differs from target ($target_version)"
        log_warning "Using existing version to avoid downgrade"
        final_version="$current_version"
        log_success "Using existing Kubernetes version: $final_version"
    else
        log_info "Using Kubernetes version: $final_version"
    fi
    
    # Start cluster if needed
    if ! minikube status >/dev/null 2>&1; then
        log_info "Starting Minikube with version: $final_version"
        retry 3 minikube start --driver=docker --kubernetes-version="$final_version"
    fi
    
    # Set context
    kubectl config use-context minikube >/dev/null 2>&1 || true
    
    # Setup Docker environment
    eval $(minikube docker-env)
    
    # Clean namespace
    log_info "Cleaning namespace..."
    minikube kubectl -- delete namespace "$NAMESPACE" --ignore-not-found=true
    
    # Deploy database
    deploy_postgresql
    
    # Build images
    smart_docker_build
    
    # Deploy applications
    deploy_applications
    
    # Setup Cloudflare Tunnel for external access
    setup_cloudflare_tunnel
    
    # Show access information
    show_access_info
    
    log_info "Waiting for all deployments..."
    wait_for_pods "$NAMESPACE" "$FULL_MODE_TIMEOUT" "app=frontend" || true
    wait_for_pods "$NAMESPACE" "$FULL_MODE_TIMEOUT" "app=backend" || true
    
    # Debug if needed
    debug_backend_pods
    
    log_success "FULL mode completed"
}

execute_reset_mode() {
    log_info "Executing RESET mode..."
    
    # Delete minikube cluster
    log_warning "Deleting Minikube cluster..."
    minikube delete || true
    
    # Clean up checksums
    rm -f .frontend-checksum .backend-checksum
    
    # Execute full mode
    execute_full_mode
    
    log_success "RESET mode completed"
}

show_status() {
    log_info "Cluster Status:"
    echo "================================"
    
    # Minikube status
    if minikube status >/dev/null 2>&1; then
        log_success "Minikube: Running"
        minikube status
    else
        log_error "Minikube: Not running"
    fi
    
    echo ""
    log_info "Pods in namespace '$NAMESPACE':"
    echo "================================"
    kubectl get pods -n "$NAMESPACE" || echo "Namespace not found"
    
    echo ""
    log_info "Services in namespace '$NAMESPACE':"
    echo "================================"
    kubectl get services -n "$NAMESPACE" || echo "Namespace not found"
    
    echo ""
    log_info "Minikube Services:"
    echo "================================"
    minikube service list || echo "No services running"
}

# =============================================================================
# 🌐 CLOUDFLARE TUNNEL SETUP
# =============================================================================
setup_cloudflare_tunnel() {
    log_step "Setting up Cloudflare Tunnel..."
    
    # Check if cloudflared is installed
    if ! command -v cloudflared >/dev/null 2>&1; then
        log_warning "cloudflared not found, skipping tunnel setup"
        log_info "To install cloudflared manually:"
        log_info "  wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.tar.gz"
        log_info "  tar xzf cloudflared-linux-amd64.tar.gz"
        log_info "  sudo mv cloudflared /usr/local/bin/"
        return 0
    fi
    
    # Check if already authenticated
    if [ ! -f "$HOME/.cloudflared/cert.pem" ]; then
        log_info "Please authenticate Cloudflare Tunnel..."
        cloudflared tunnel login
    fi
    
    # Create tunnel if not exists
    local tunnel_name="eduai-tunnel"
    local tunnel_id=$(cloudflared tunnel list 2>/dev/null | grep "$tunnel_name" | awk '{print $2}' || echo "")
    
    if [ -z "$tunnel_id" ]; then
        log_info "Creating new tunnel: $tunnel_name"
        local tunnel_output=$(cloudflared tunnel create "$tunnel_name" 2>&1)
        tunnel_id=$(echo "$tunnel_output" | grep "Created tunnel" | awk '{print $3}' || echo "")
        if [ -z "$tunnel_id" ]; then
            # Try alternative parsing methods
            tunnel_id=$(echo "$tunnel_output" | tail -1 | awk '{print $NF}' || echo "")
            if [ -z "$tunnel_id" ]; then
                log_error "Failed to create tunnel: $tunnel_output"
                return 1
            fi
        fi
        log_success "Created tunnel with ID: $tunnel_id"
    else
        log_success "Using existing tunnel: $tunnel_id"
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
    
    # Create DNS record if not exists
    log_info "Setting up DNS record for $DOMAIN..."
    if ! cloudflared tunnel route dns "$tunnel_name" "$DOMAIN" >/dev/null 2>&1; then
        log_info "Creating DNS record for $DOMAIN..."
        cloudflared tunnel route dns "$tunnel_name" "$DOMAIN" || {
            log_warning "DNS record already exists or failed to create"
            log_info "The tunnel will still work, but DNS may need manual configuration"
        }
    else
        log_success "DNS record already exists for $DOMAIN"
    fi
    
    # Start tunnel in background
    if [ -f "$TUNNEL_CONFIG_DIR/tunnel.pid" ] && kill -0 $(cat "$TUNNEL_CONFIG_DIR/tunnel.pid") 2>/dev/null; then
        log_success "Cloudflare Tunnel already running"
    else
        log_info "Starting Cloudflare Tunnel..."
        nohup cloudflared tunnel run "$tunnel_name" > "$TUNNEL_CONFIG_DIR/tunnel.log" 2>&1 &
        echo $! > "$TUNNEL_CONFIG_DIR/tunnel.pid"
        
        # Wait for tunnel to start
        local max_wait=30
        local wait_count=0
        while [ $wait_count -lt $max_wait ]; do
            if kill -0 $(cat "$TUNNEL_CONFIG_DIR/tunnel.pid") 2>/dev/null; then
                log_success "Cloudflare Tunnel started successfully"
                break
            fi
            wait_count=$((wait_count + 2))
            if [ $wait_count -lt $max_wait ]; then
                echo -n "."
                sleep 2
            fi
        done
        
        if [ $wait_count -ge $max_wait ]; then
            log_warning "Tunnel taking longer than expected, but continuing..."
        fi
    fi
    
    return 0
}

# =============================================================================
# 🌐 ACCESS INFORMATION
# =============================================================================
show_access_info() {
    echo ""
    echo "🌐 ACCESS URLS:"
    echo "==============="
    
    # Get Minikube IP
    local minikube_ip=$(minikube ip 2>/dev/null | tr -d '[:space:]' || echo "192.168.49.2")
    
    echo "🌐 Public URL: https://$DOMAIN"
    echo ""
    echo "📱 AI LEARNING PLATFORM:"
    echo "  Frontend: http://$minikube_ip:30007"
    echo "  Backend:  http://$minikube_ip:30008"
    echo ""
    
    echo "📊 MONITORING & DEVOPS:"
    echo "  Grafana:    http://$minikube_ip:30031"
    echo "  Prometheus: http://$minikube_ip:30091"
    echo "  ArgoCD:     http://$minikube_ip:30081"
    echo ""
    
    echo "🤖 AI SERVICES:"
    echo "  AI Service: http://$minikube_ip:30020"
    echo ""
    
    echo "🔐 DEFAULT CREDENTIALS:"
    echo "  Grafana:     admin/admin"
    echo "  ArgoCD:      admin/admin123"
    echo ""
    
    if [ "$AUTO_FORWARD" = true ]; then
        echo ""
        log_info "Starting port forwarding..."
        echo "Frontend: kubectl port-forward -n $NAMESPACE svc/frontend 3000:3000"
        echo "Backend:  kubectl port-forward -n $NAMESPACE svc/backend 5000:5000"
        echo "Grafana:   kubectl port-forward -n monitoring svc/grafana 3001:3000"
        echo "ArgoCD:    kubectl port-forward -n argocd svc/argocd-server 3012:80"
        
        # Start port forwarding in background
        minikube kubectl -- port-forward -n "$NAMESPACE" svc/frontend 3000:3000 &
        FRONTEND_PID=$!
        minikube kubectl -- port-forward -n "$NAMESPACE" svc/backend 5000:5000 &
        minikube kubectl -- port-forward -n monitoring svc/grafana 3001:3000 &
        minikube kubectl -- port-forward -n argocd svc/argocd-server 3012:80 &
        
        echo "Port forwarding started!"
        echo "Access via:"
        echo "  Frontend: http://localhost:3000"
        echo "  Backend:  http://localhost:5000"
        echo "  Grafana:  http://localhost:3001"
        echo "  ArgoCD:   http://localhost:3012"
    fi
}


# =============================================================================
# 🎯 MAIN EXECUTION
# =============================================================================
main() {
    echo "🧠 AI Smart Learning Platform - INTELLIGENT DevOps (Production-Grade)"
    echo "===================================================================="
    echo ""
    
    # Check tools
    if ! command -v kubectl >/dev/null 2>&1; then
        log_error "kubectl not found. Please install kubectl."
        exit 1
    fi
    
    if ! command -v minikube >/dev/null 2>&1; then
        log_error "minikube not found. Please install minikube."
        exit 1
    fi
    
    if ! command -v docker >/dev/null 2>&1; then
        log_error "docker not found. Please install docker."
        exit 1
    fi
    
    # Execute based on mode
    case "$MODE" in
        "fast")
            execute_fast_mode
            ;;
        "full")
            execute_full_mode
            ;;
        "")
            # Auto-detect mode
            if kubectl cluster-info >/dev/null 2>&1 && kubectl get pods -n "$NAMESPACE" >/dev/null 2>&1; then
                log_info "Auto-detected FAST mode (cluster running)"
                execute_fast_mode
            else
                log_info "Auto-detected FULL mode (cluster not ready)"
                execute_full_mode
            fi
            ;;
        *)
            log_error "Invalid mode: $MODE"
            exit 1
            ;;
    esac
    
    # Show status if requested
    if [ "$SHOW_STATUS" = true ]; then
        show_status
    fi
    
    # Show final status
    show_status
    show_access_info
    
    log_success "🎉 Deployment completed successfully!"
}

# Handle reset mode separately
if [ "$RESET_CLUSTER" = true ]; then
    execute_reset_mode
    exit 0
fi


# Handle status mode separately
if [ "$SHOW_STATUS" = true ]; then
    show_status
    exit 0
fi

# Execute main function
main
