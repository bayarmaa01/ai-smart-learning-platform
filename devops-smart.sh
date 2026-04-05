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
    
    kubectl wait --for=condition=Ready pods -n "$namespace" $selector --timeout="${timeout}s" || {
        log_warning "Some pods are not ready within ${timeout}s"
        return 1
    }
}

# =============================================================================
# 🚀 KUBERNETES VERSION DETECTION
# =============================================================================
detect_k8s_version() {
    local version=""
    
    # Try to get version from running cluster
    if kubectl cluster-info >/dev/null 2>&1; then
        version=$(kubectl version --output=json 2>/dev/null | jq -r '.serverVersion.gitVersion' 2>/dev/null || echo "")
        if [ -n "$version" ]; then
            log_success "Detected running Kubernetes version: $version"
            echo "$version"
            return 0
        fi
    fi
    
    # Fallback to minikube version
    if minikube status >/dev/null 2>&1; then
        version=$(minikube kubectl -- version --short 2>/dev/null | grep "Server Version" | awk '{print $3}' || echo "")
        if [ -n "$version" ]; then
            log_success "Detected Minikube Kubernetes version: $version"
            echo "$version"
            return 0
        fi
    fi
    
    # Return default version
    log_info "No cluster detected, using default version: $DEFAULT_K8S_VERSION"
    echo "$DEFAULT_K8S_VERSION"
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
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy PostgreSQL
    cat <<EOF | kubectl apply -f -
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
      containers:
      - name: postgres
        image: postgres:15-alpine
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_DB
          value: "eduai"
        - name: POSTGRES_USER
          value: "postgres"
        - name: POSTGRES_PASSWORD
          value: "postgres123"
        - name: POSTGRES_HOST_AUTH_METHOD
          value: "trust"
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
        readinessProbe:
          exec:
            command:
            - pg_isready
          initialDelaySeconds: 10
          periodSeconds: 5
        livenessProbe:
          exec:
            command:
            - pg_isready
          initialDelaySeconds: 30
          periodSeconds: 10
      volumes:
      - name: postgres-storage
        emptyDir: {}
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
    if ! wait_for_pods "$NAMESPACE" 120 "app=postgres"; then
        log_error "PostgreSQL failed to start"
        return 1
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
    cat <<EOF | kubectl apply -f -
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
          runAsUser: 0
          runAsGroup: 0
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: false
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
    cat <<EOF | kubectl apply -f -
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
          value: "postgresql://postgres:postgres123@postgres:5432/eduai"
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
          initialDelaySeconds: 15
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
    
    local failed_pods=$(kubectl get pods -n "$NAMESPACE" -l app=backend -o jsonpath='{.items[?(@.status.phase=="Failed")].metadata.name}' 2>/dev/null || echo "")
    local crashloop_pods=$(kubectl get pods -n "$NAMESPACE" -l app=backend -o jsonpath='{.items[?(@.status.reason=="CrashLoopBackOff")].metadata.name}' 2>/dev/null || echo "")
    
    if [ -n "$failed_pods" ] || [ -n "$crashloop_pods" ]; then
        log_warning "Found problematic backend pods, analyzing logs..."
        
        for pod in $failed_pods $crashloop_pods; do
            if [ -n "$pod" ]; then
                log_info "Analyzing pod: $pod"
                
                # Get previous logs
                local logs=$(kubectl logs "$pod" -n "$NAMESPACE" --previous 2>/dev/null || echo "")
                
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
                
                # Show sample logs
                if [ -n "$logs" ]; then
                    log_info "Last 10 lines from pod $pod:"
                    echo "$logs" | tail -10
                fi
            fi
        done
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
    kubectl rollout restart deployment/frontend -n "$NAMESPACE"
    kubectl rollout restart deployment/backend -n "$NAMESPACE"
    
    # Wait for pods
    wait_for_pods "$NAMESPACE" "$FAST_MODE_TIMEOUT" "app=frontend" || true
    wait_for_pods "$NAMESPACE" "$FAST_MODE_TIMEOUT" "app=backend" || true
    
    # Debug if needed
    debug_backend_pods
    
    log_success "FAST mode completed"
}

execute_full_mode() {
    log_info "Executing FULL mode..."
    
    # Detect Kubernetes version
    local k8s_version=$(detect_k8s_version)
    
    # Start cluster if needed
    if ! minikube status >/dev/null 2>&1; then
        log_info "Starting Minikube with version: $k8s_version"
        retry 3 minikube start --driver=docker --kubernetes-version="$k8s_version"
    fi
    
    # Set context
    kubectl config use-context minikube >/dev/null 2>&1 || true
    
    # Setup Docker environment
    eval $(minikube docker-env)
    
    # Clean namespace
    log_info "Cleaning namespace..."
    kubectl delete namespace "$NAMESPACE" --ignore-not-found=true
    
    # Deploy database
    deploy_postgresql
    
    # Build images
    smart_docker_build
    
    # Deploy applications
    deploy_applications
    
    # Wait for all pods
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
# 🌐 ACCESS INFORMATION
# =============================================================================
show_access_info() {
    echo ""
    echo "🌐 ACCESS URLS:"
    echo "==============="
    
    # Get Minikube IP
    local minikube_ip=$(minikube ip 2>/dev/null || echo "192.168.49.2")
    
    echo "Frontend: http://$minikube_ip:30007"
    echo "Backend:  http://$minikube_ip:30008"
    echo ""
    echo "🌐 External Domain: https://$DOMAIN"
    
    if [ "$AUTO_FORWARD" = true ]; then
        echo ""
        log_info "Starting port forwarding..."
        echo "Frontend: kubectl port-forward -n $NAMESPACE svc/frontend 3000:3000"
        echo "Backend:  kubectl port-forward -n $NAMESPACE svc/backend 5000:5000"
        
        # Start port forwarding in background
        kubectl port-forward -n "$NAMESPACE" svc/frontend 3000:3000 &
        FRONTEND_PID=$!
        kubectl port-forward -n "$NAMESPACE" svc/backend 5000:5000 &
        BACKEND_PID=$!
        
        echo "Port forwarding started (PIDs: $FRONTEND_PID, $BACKEND_PID)"
        echo "Access via: http://localhost:3000 (frontend) and http://localhost:5000 (backend)"
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

# Handle status mode separately
if [ "$SHOW_STATUS" = true ]; then
    show_status
    exit 0
fi

# Execute main function
main
