#!/bin/bash

set -euo pipefail

# =============================================================================
# 🧠 AI SMART LEARNING PLATFORM - INTELLIGENT DEVOPS (PRODUCTION-GRADE)
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
DEFAULT_K8S_VERSION="v1.34.0"

# Parse arguments
FORCE_BUILD=false
RESET_CLUSTER=false
SHOW_STATUS=false
AUTO_FORWARD=false
DEBUG_CAREER_COACH=false
FIX_CAREER_COACH=false

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
        --debug-career)
            DEBUG_CAREER_COACH=true
            shift
            ;;
        --fix-career)
            FIX_CAREER_COACH=true
            shift
            ;;
        *)
            echo "Usage: $0 [--fast|--full|--reset|--status|--forward|--force-build|--debug-career|--fix-career]"
            echo ""
            echo "Modes:"
            echo "  --fast         Skip rebuild, only restart pods"
            echo "  --full         Rebuild images + redeploy everything"
            echo "  --reset        Delete minikube + clean start"
            echo "  --status       Show cluster + pod health"
            echo "  --forward      Auto port-forward services"
            echo "  --force-build  Force rebuild all images"
            echo "  --debug-career Debug existing Career Coach services"
            echo "  --fix-career   Fix existing Career Coach services"
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
    log_step "Deploying PostgreSQL database..."
    
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
    return 0
}

# =============================================================================
# 🐳 SMART DOCKER BUILD
# =============================================================================
smart_docker_build() {
    log_step "Building Docker images..."
    
    # Check if images exist in Minikube Docker environment
    eval $(minikube docker-env)
    local frontend_exists=false
    local backend_exists=false
    
    if docker images --format "table {{.Repository}}:{{.Tag}}" | grep -q "eduai-frontend:latest"; then
        frontend_exists=true
    fi
    
    if docker images --format "table {{.Repository}}:{{.Tag}}" | grep -q "eduai-backend:latest"; then
        backend_exists=true
    fi
    
    # Force rebuild if requested
    if [ "$FORCE_BUILD" = true ]; then
        log_info "Force build requested, rebuilding all images"
        if [ "$frontend_exists" = true ]; then
            docker rmi eduai-frontend:latest >/dev/null 2>&1 || true
            frontend_exists=false
        fi
        if [ "$backend_exists" = true ]; then
            docker rmi eduai-backend:latest >/dev/null 2>&1 || true
            backend_exists=false
        fi
    fi
    
    # Build frontend if needed
    if [ "$frontend_exists" = false ] && [ -d "frontend" ]; then
        log_info "Building frontend image..."
        retry 3 docker build -t eduai-frontend:latest ./frontend
        log_success "Frontend image built"
    elif [ "$frontend_exists" = true ]; then
        log_info "Frontend image already exists, skipping build"
    fi
    
    # Build backend if needed
    if [ "$backend_exists" = false ] && [ -d "backend" ]; then
        log_info "Building backend image..."
        retry 3 docker build -t eduai-backend:latest ./backend
        log_success "Backend image built"
    elif [ "$backend_exists" = true ]; then
        log_info "Backend image already exists, skipping build"
    fi
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
        - containerPort: 80
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
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        livenessProbe:
          httpGet:
            path: /
            port: 80
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
    targetPort: 80
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
          initialDelaySeconds: 45
          periodSeconds: 15
          timeoutSeconds: 10
          failureThreshold: 3
        livenessProbe:
          httpGet:
            path: /api/health
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
        log_info "Installing cloudflared..."
        if command -v wget >/dev/null 2>&1; then
            wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -O /tmp/cloudflared.deb
            sudo dpkg -i /tmp/cloudflared.deb || {
                log_info "Trying alternative installation method..."
                curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.tar.gz | tar xz
                sudo mv cloudflared /usr/local/bin/
            }
        elif command -v curl >/dev/null 2>&1; then
            curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.tar.gz | tar xz
            sudo mv cloudflared /usr/local/bin/
        else
            log_error "Neither wget nor curl available for cloudflared installation"
            return 1
        fi
    fi
    
    # Check if already authenticated
    if [ ! -f "$HOME/.cloudflared/cert.pem" ]; then
        log_info "Please authenticate Cloudflare Tunnel..."
        cloudflared tunnel login
    fi
    
    # Create tunnel if not exists
    local tunnel_name="eduai-tunnel"
    local tunnel_id=$(cloudflared tunnel list --format=json | jq -r ".[] | select(.name == \"$tunnel_name\") | .uuid" 2>/dev/null || echo "")
    
    if [ -z "$tunnel_id" ]; then
        log_info "Creating new tunnel: $tunnel_name"
        tunnel_id=$(cloudflared tunnel create "$tunnel_name" --format=json | jq -r .result.uuid)
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
    if ! cloudflared tunnel route dns "$tunnel_name" "$DOMAIN" >/dev/null 2>&1; then
        cloudflared tunnel route dns "$tunnel_name" "$DOMAIN"
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
# 🔍 EXISTING SERVICES DEBUG & FIX
# =============================================================================
debug_career_coach_services() {
    log_step "Debugging Career Coach services..."
    
    # Check career-coach-prod namespace
    if kubectl get namespace career-coach-prod >/dev/null 2>&1; then
        log_info "Found career-coach-prod namespace, checking services..."
        
        # Check AI Service
        local ai_service_pods=$(kubectl get pods -n career-coach-prod -l app=ai-service -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
        if [ -n "$ai_service_pods" ]; then
            log_info "AI Service pods: $ai_service_pods"
            for pod in $ai_service_pods; do
                log_info "Checking AI Service pod: $pod"
                local pod_status=$(kubectl get pod "$pod" -n career-coach-prod -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
                log_info "  Status: $pod_status"
                
                if [ "$pod_status" = "Running" ]; then
                    # Check metrics endpoint
                    log_info "  Testing metrics endpoint..."
                    local metrics_response=$(kubectl exec "$pod" -n career-coach-prod -- curl -s -o /dev/null -w "%{http_code}" http://localhost:5100/metrics 2>/dev/null || echo "000")
                    if [ "$metrics_response" = "404" ]; then
                        log_warning "  AI Service metrics endpoint returns 404 - service may not have /metrics endpoint"
                    elif [ "$metrics_response" = "200" ]; then
                        log_success "  AI Service metrics endpoint working"
                    else
                        log_warning "  AI Service metrics endpoint returned: $metrics_response"
                    fi
                    
                    # Check service logs
                    log_info "  Recent logs (last 5 lines):"
                    kubectl logs "$pod" -n career-coach-prod --tail=5 2>/dev/null || log_warning "  Could not fetch logs"
                fi
            done
        fi
        
        # Check Backend Service
        local backend_pods=$(kubectl get pods -n career-coach-prod -l app=backend -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
        if [ -n "$backend_pods" ]; then
            log_info "Backend Service pods: $backend_pods"
            for pod in $backend_pods; do
                log_info "Checking Backend pod: $pod"
                local pod_status=$(kubectl get pod "$pod" -n career-coach-prod -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
                log_info "  Status: $pod_status"
                
                if [ "$pod_status" = "Running" ]; then
                    # Check metrics endpoint
                    log_info "  Testing metrics endpoint..."
                    local metrics_response=$(kubectl exec "$pod" -n career-coach-prod -- curl -s -o /dev/null -w "%{http_code}" http://localhost:4100/metrics 2>/dev/null || echo "000")
                    if [ "$metrics_response" = "500" ]; then
                        log_error "  Backend Service metrics endpoint returns 500 - internal error"
                        # Get error logs
                        log_info "  Error logs (last 10 lines):"
                        kubectl logs "$pod" -n career-coach-prod --tail=10 2>/dev/null || log_warning "  Could not fetch logs"
                    elif [ "$metrics_response" = "200" ]; then
                        log_success "  Backend Service metrics endpoint working"
                    else
                        log_warning "  Backend Service metrics endpoint returned: $metrics_response"
                    fi
                fi
            done
        fi
        
        # Show services status
        log_info "Career Coach services:"
        kubectl get services -n career-coach-prod 2>/dev/null || log_warning "  Could not get services"
        
    else
        log_info "No career-coach-prod namespace found"
    fi
}

fix_career_coach_services() {
    log_step "Attempting to fix Career Coach services..."
    
    if kubectl get namespace career-coach-prod >/dev/null 2>&1; then
        # Restart problematic services
        log_info "Restarting AI Service..."
        kubectl rollout restart deployment/ai-service -n career-coach-prod 2>/dev/null || log_warning "Could not restart AI Service"
        
        log_info "Restarting Backend Service..."
        kubectl rollout restart deployment/backend -n career-coach-prod 2>/dev/null || log_warning "Could not restart Backend Service"
        
        # Wait for rollout
        log_info "Waiting for rollout to complete..."
        kubectl rollout status deployment/ai-service -n career-coach-prod --timeout=60s 2>/dev/null || log_warning "AI Service rollout timeout"
        kubectl rollout status deployment/backend -n career-coach-prod --timeout=60s 2>/dev/null || log_warning "Backend Service rollout timeout"
        
        log_success "Career Coach services restart attempted"
    else
        log_warning "No career-coach-prod namespace found"
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
        "FAST")
            execute_fast_mode
            ;;
        "FULL")
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

# Handle debug career coach mode separately
if [ "$DEBUG_CAREER_COACH" = true ]; then
    debug_career_coach_services
    exit 0
fi

# Handle fix career coach mode separately
if [ "$FIX_CAREER_COACH" = true ]; then
    fix_career_coach_services
    exit 0
fi

# Handle status mode separately
if [ "$SHOW_STATUS" = true ]; then
    show_status
    exit 0
fi

# Execute main function
main
