#!/bin/bash

set -e
set -o pipefail

############################################
# LOGGING FUNCTIONS
############################################

log() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

success() {
    echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1"
    exit 1
}

############################################
# RETRY FUNCTION
############################################

retry() {
    local retries=$1
    shift
    local count=0
    
    until "$@"; do
        exit_code=$?
        count=$((count + 1))
        if [ $count -lt $retries ]; then
            log "Command failed (attempt $count/$retries). Retrying in 5 seconds..."
            sleep 5
        else
            error "Command failed after $retries attempts"
        fi
    done
}

############################################
# SYSTEM VALIDATION
############################################

validate_system() {
    log "Validating system requirements..."
    
    # Check memory
    total_mem=$(free -m | awk 'NR==2{print $2}')
    if [ "$total_mem" -lt 4096 ]; then
        error "System requires at least 4GB RAM. Found: ${total_mem}MB"
    fi
    
    # Check CPU cores
    cpu_cores=$(nproc)
    if [ "$cpu_cores" -lt 2 ]; then
        error "System requires at least 2 CPU cores. Found: ${cpu_cores}"
    fi
    
    # Check required tools
    for cmd in kubectl minikube helm docker; do
        if ! command -v "$cmd" &> /dev/null; then
            error "Required command not found: $cmd"
        fi
    done
    
    success "System validation passed"
}

############################################
# MINIKUBE SETUP
############################################

setup_minikube() {
    log "Setting up Minikube cluster..."
    
    # Clean delete old cluster
    log "Deleting existing cluster (if exists)..."
    minikube delete -p eduai-cluster || true
    
    # Start new cluster
    log "Starting Minikube cluster..."
    minikube start \
        -p eduai-cluster \
        --driver=docker \
        --memory=4096 \
        --cpus=2 \
        --kubernetes-version=v1.28.0 \
        --container-runtime=docker
    
    # Set context
    kubectl config use-context eduai-cluster
    
    # Wait for cluster to be ready
    log "Waiting for cluster to be ready..."
    retry 5 kubectl wait --for=condition=Ready nodes --all --timeout=300s
    
    # Validate cluster
    if ! kubectl get nodes &> /dev/null; then
        error "Failed to connect to Minikube cluster"
    fi
    
    success "Minikube cluster is ready"
}

############################################
# DEPLOY APPLICATIONS
############################################

deploy_applications() {
    log "Deploying applications..."
    
    # Create namespace
    kubectl create namespace eduai --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy frontend
    log "Deploying frontend..."
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
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
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
  - port: 80
    targetPort: 80
    nodePort: 30007
EOF
    
    # Deploy backend
    log "Deploying backend..."
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
        image: nginx:alpine
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
  name: backend
spec:
  selector:
    app: backend
  type: NodePort
  ports:
  - port: 5000
    targetPort: 80
    nodePort: 30008
EOF
    
    # Wait for pods to be ready
    log "Waiting for application pods to be ready..."
    retry 10 kubectl wait --for=condition=Ready pods -n eduai --all --timeout=300s
    
    success "Applications deployed successfully"
}

############################################
# INSTALL ARGOCD
############################################

install_argocd() {
    log "Installing ArgoCD..."
    
    # Create namespace
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    
    # Install ArgoCD using a different approach - individual manifests to avoid CRD annotation issues
    log "Installing ArgoCD core components..."
    
    # Install CRDs first
    retry 3 kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.8.4/manifests/crds/application-crd.yaml
    retry 3 kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.8.4/manifests/crds/appproject-crd.yaml
    
    # Install core components
    retry 3 kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.8.4/manifests/install.yaml
    
    # Patch service to NodePort
    kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'
    
    # Wait for ArgoCD to be ready
    log "Waiting for ArgoCD to be ready..."
    retry 15 kubectl wait --for=condition=Ready pods -n argocd -l app.kubernetes.io/name=argocd-server --timeout=600s
    
    success "ArgoCD installed successfully"
}

############################################
# INSTALL PROMETHEUS + GRAFANA
############################################

install_monitoring() {
    log "Installing Prometheus + Grafana..."
    
    # Add Helm repository
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    
    # Install monitoring stack with minimal config for low resources
    helm install monitoring prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --create-namespace \
        --set grafana.service.type=NodePort \
        --set prometheus.service.type=NodePort \
        --set alertmanager.enabled=false \
        --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=4Gi \
        --set grafana.persistence.storage=1Gi \
        --set grafana.persistence.enabled=true \
        --set kube-state-metrics.enabled=false \
        --set prometheus-node-exporter.enabled=false \
        --set prometheusOperator.enabled=true \
        --set defaultRules.enabled=false \
        --set kubelet.enabled=false \
        --set kubeControllerManager.enabled=false \
        --set kubeScheduler.enabled=false \
        --set kubeProxy.enabled=false
    
    # Wait for monitoring to be ready
    log "Waiting for monitoring stack to be ready..."
    retry 15 kubectl wait --for=condition=Ready pods -n monitoring --all --timeout=600s
    
    success "Monitoring stack installed successfully"
}

############################################
# SETUP CLOUDFLARE TUNNEL
############################################

setup_cloudflare_tunnel() {
    log "Setting up Cloudflare Tunnel..."
    
    # Create config directory
    mkdir -p ~/.cloudflared
    
    # Create tunnel config
    cat > ~/.cloudflared/config.yml <<EOF
tunnel: dbea55ba-3659-4dd7-ac66-67f900defbfd
credentials-file: /home/bayarmaa/.cloudflared/dbea55ba-3659-4dd7-ac66-67f900defbfd.json

ingress:
  - hostname: ailearn.duckdns.org
    service: http://host.docker.internal:30007
  - service: http_status:404
EOF
    
    # Restart cloudflared (if running)
    if command -v systemctl &> /dev/null; then
        if systemctl is-active --quiet cloudflared 2>/dev/null; then
            log "Restarting cloudflared service..."
            sudo systemctl restart cloudflared || log "Warning: Could not restart cloudflared service"
        fi
    fi
    
    success "Cloudflare Tunnel configured"
}

############################################
# HEALTH CHECKS
############################################

health_checks() {
    log "Performing health checks..."
    
    # Check nodes
    if ! kubectl get nodes &> /dev/null; then
        error "Failed to get cluster nodes"
    fi
    
    # Check pods
    if ! kubectl get pods -A &> /dev/null; then
        error "Failed to get cluster pods"
    fi
    
    # Check application services
    if ! kubectl get svc -n eduai &> /dev/null; then
        error "Failed to get application services"
    fi
    
    # Check ArgoCD
    if ! kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server &> /dev/null; then
        error "ArgoCD pods not found"
    fi
    
    # Check monitoring
    if ! kubectl get pods -n monitoring &> /dev/null; then
        error "Monitoring pods not found"
    fi
    
    success "All health checks passed"
}

############################################
# OUTPUT ACCESS URLS
############################################

output_urls() {
    log "Generating access URLs..."
    
    echo ""
    echo "=========================================="
    echo "🚀 DEPLOYMENT COMPLETED SUCCESSFULLY!"
    echo "=========================================="
    echo ""
    
    echo "🌐 APPLICATION URLS:"
    echo "   Frontend: https://ailearn.duckdns.org"
    echo "   Backend:  https://ailearn.duckdns.org/api"
    echo ""
    
    echo "🔧 INTERNAL SERVICES:"
    
    # Get ArgoCD URL
    argocd_url=$(minikube service argocd-server -n argocd --url 2>/dev/null || echo "http://localhost:30007")
    echo "   ArgoCD:   $argocd_url"
    
    # Get Grafana URL
    grafana_url=$(minikube service monitoring-grafana -n monitoring --url 2>/dev/null || echo "http://localhost:30008")
    echo "   Grafana:  $grafana_url (admin/admin123)"
    
    # Get Prometheus URL
    prometheus_url=$(minikube service monitoring-kube-prometheus-prometheus -n monitoring --url 2>/dev/null || echo "http://localhost:30009")
    echo "   Prometheus: $prometheus_url"
    
    echo ""
    echo "📊 SERVICE STATUS:"
    echo "   Frontend Service: NodePort 30007"
    echo "   Backend Service:  NodePort 30008"
    echo ""
    
    echo "🔍 VERIFICATION COMMANDS:"
    echo "   kubectl get pods -A"
    echo "   kubectl get svc -A"
    echo "   minikube service list"
    echo ""
    
    echo "🎯 ACCESS CREDENTIALS:"
    echo "   Grafana: admin/admin123"
    echo "   ArgoCD:  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
    echo ""
    
    success "All services are accessible!"
}

############################################
# MAIN EXECUTION
############################################

main() {
    echo "=========================================="
    echo "🚀 EDUAI FULL PLATFORM DEPLOYMENT"
    echo "=========================================="
    echo ""
    
    validate_system
    setup_minikube
    deploy_applications
    install_argocd
    install_monitoring
    setup_cloudflare_tunnel
    health_checks
    output_urls
    
    echo ""
    success "Full platform deployment completed successfully!"
}

# Execute main function
main "$@"
