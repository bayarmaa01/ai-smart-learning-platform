#!/bin/bash

# =============================================================================
# Production-Grade Kubernetes Monitoring Stack Setup
# Uses kube-prometheus-stack via Helm for Minikube
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="monitoring"
HELM_RELEASE="kube-prometheus"
GRAFANA_NODEPORT=30010
GRAFANA_USER="admin"
GRAFANA_PASSWORD="admin"

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

# =============================================================================
# STEP 1: Prerequisites Check
# =============================================================================

check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is not installed or not in PATH"
    fi
    
    # Check if Minikube is running
    if ! kubectl cluster-info &> /dev/null; then
        error "Kubernetes cluster is not accessible. Please start Minikube first."
    fi
    
    # Check cluster context
    local current_context=$(kubectl config current-context)
    log "Using Kubernetes context: $current_context"
    
    success "Prerequisites check completed"
}

# =============================================================================
# STEP 2: Install Helm
# =============================================================================

install_helm() {
    log "Checking Helm installation..."
    
    if command -v helm &> /dev/null; then
        local helm_version=$(helm version --template='{{.Version}}')
        success "Helm is already installed: $helm_version"
        return
    fi
    
    log "Installing Helm..."
    
    # Download and install Helm
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
    
    # Verify installation
    if ! command -v helm &> /dev/null; then
        error "Helm installation failed"
    fi
    
    local helm_version=$(helm version --template='{{.Version}}')
    success "Helm installed successfully: $helm_version"
    
    # Clean up
    rm -f get_helm.sh
}

# =============================================================================
# STEP 3: Add Helm Repositories
# =============================================================================

add_helm_repos() {
    log "Adding Helm repositories..."
    
    # Add Prometheus community repository
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add grafana https://grafana.github.io/helm-charts
    
    # Update repositories
    helm repo update
    
    success "Helm repositories added and updated"
}

# =============================================================================
# STEP 4: Create Namespace
# =============================================================================

create_namespace() {
    log "Creating monitoring namespace..."
    
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    success "Namespace '$NAMESPACE' created/verified"
}

# =============================================================================
# STEP 5: Prepare Custom Values
# =============================================================================

prepare_values() {
    log "Preparing custom Helm values..."
    
    cat > monitoring-values.yaml <<EOF
# Production-grade kube-prometheus-stack configuration
# Optimized for Minikube with full monitoring capabilities

# Global configuration
global:
  imageRegistry: ""
  imagePullSecrets: []

# Prometheus Operator configuration
prometheusOperator:
  enabled: true
  createCustomResource: true
  admissionWebhooks:
    enabled: true
  tls:
    enabled: true

# Prometheus configuration
prometheus:
  enabled: true
  prometheusSpec:
    retention: 30d
    retentionSize: "10GB"
    enableAdminAPI: true
    walCompression: true
    
    # Storage configuration
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: standard
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 8Gi
    
    # Resources
    resources:
      requests:
        cpu: 200m
        memory: 400Mi
      limits:
        cpu: 1000m
        memory: 2000Mi
    
    # Service configuration
    service:
      type: ClusterIP
      port: 9090
      targetPort: 9090
    
    # Service Monitor configuration
    serviceMonitorSelectorNilUsesHelmValues: false
    serviceMonitorSelector: {}
    serviceMonitorNamespaceSelector: {}
    
    # Pod Monitor configuration
    podMonitorSelectorNilUsesHelmValues: false
    podMonitorSelector: {}
    podMonitorNamespaceSelector: {}
    
    # Rule configuration
    ruleSelectorNilUsesHelmValues: false
    ruleSelector: {}
    ruleNamespaceSelector: {}

# AlertManager configuration
alertmanager:
  enabled: true
  alertmanagerSpec:
    retention: 120h
    storage:
      volumeClaimTemplate:
        spec:
          storageClassName: standard
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 2Gi
    
    # Resources
    resources:
      requests:
        cpu: 100m
        memory: 100Mi
      limits:
        cpu: 200m
        memory: 500Mi
    
    # Configuration
    config:
      global:
        smtp_smarthost: 'localhost:587'
        smtp_from: 'alerts@eduai.com'
      
      route:
        group_by: ['alertname']
        group_wait: 10s
        group_interval: 10s
        repeat_interval: 1h
        receiver: 'web.hook'
      
      receivers:
        - name: 'web.hook'
          webhook_configs:
            - url: 'http://127.0.0.1:5001/'

# Grafana configuration
grafana:
  enabled: true
  namespaceOverride: $NAMESPACE
  
  # Admin credentials
  adminUser: $GRAFANA_USER
  adminPassword: $GRAFANA_PASSWORD
  
  # Service configuration
  service:
    type: NodePort
    port: 3000
    targetPort: 3000
    nodePort: $GRAFANA_NODEPORT
    annotations: {}
    
  # Ingress configuration (disabled for Minikube)
  ingress:
    enabled: false
  
  # Resources
  resources:
    requests:
      cpu: 250m
      memory: 250Mi
    limits:
      cpu: 500m
      memory: 500Mi
  
  # Persistence
  persistence:
    enabled: true
    type: pvc
    storageClassName: standard
    accessModes: ["ReadWriteOnce"]
    size: 2Gi
  
  # Data sources
  datasources:
    datasources.yaml:
      apiVersion: 1
      datasources:
        - name: Prometheus
          type: prometheus
          url: http://kube-prometheus-stack-prometheus.$NAMESPACE.svc.cluster.local:9090
          access: proxy
          isDefault: true
          jsonData:
            timeInterval: "5s"
            queryTimeout: "60s"
            httpMethod: "POST"
        - name: Alertmanager
          type: alertmanager
          url: http://kube-prometheus-stack-alertmanager.$NAMESPACE.svc.cluster.local:9093
          access: proxy
  
  # Dashboard providers
  dashboardProviders:
    dashboardproviders.yaml:
      apiVersion: 1
      providers:
        - name: 'default'
          orgId: 1
          folder: ''
          type: file
          disableDeletion: false
          editable: true
          options:
            path: /var/lib/grafana/dashboards/default
  
  # Pre-configured dashboards
  dashboards:
    default:
      # Kubernetes General Monitoring
      kubernetes-general:
        gnetId: 7249
        revision: 1
        datasource: Prometheus
      
      # Kubernetes Cluster Monitoring
      kubernetes-cluster:
        gnetId: 8588
        revision: 1
        datasource: Prometheus
      
      # Node Exporter Full
      node-exporter-full:
        gnetId: 1860
        revision: 23
        datasource: Prometheus
      
      # Pod Monitoring
      pod-monitoring:
        gnetId: 6417
        revision: 1
        datasource: Prometheus
      
      # API Server Monitoring
      api-server:
        gnetId: 15757
        revision: 1
        datasource: Prometheus
      
      # Kubernetes Compute Resources
      compute-resources:
        gnetId: 405
        revision: 1
        datasource: Prometheus
      
      # Kubernetes Network Monitoring
      network-monitoring:
        gnetId: 3132
        revision: 1
        datasource: Prometheus
      
      # Kubernetes State Metrics
      state-metrics:
        gnetId: 13332
        revision: 1
        datasource: Prometheus

# Node Exporter configuration
nodeExporter:
  enabled: true
  namespaceOverride: $NAMESPACE
  serviceMonitor:
    enabled: true
    defaults:
      labels:
        release: kube-prometheus
    targets:
      - config:
        - scheme: http
        - port: http
        - path: /metrics

# kube-state-metrics configuration
kubeStateMetrics:
  enabled: true
  namespaceOverride: $NAMESPACE
  serviceMonitor:
    enabled: true
    defaults:
      labels:
        release: kube-prometheus

# Default service monitors
defaultServiceMonitors:
  enabled: true
  monitors:
    - name: kube-apiserver
      selector:
        matchLabels:
          component: kube-apiserver
      endpoints:
        - port: https
          scheme: https
          tlsConfig:
            caFile: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
            serverName: kubernetes
          bearerTokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
          metricRelabelings:
            - sourceLabels: [__name__]
              regex: 'apiserver_request_(latency_seconds|duration_seconds|total)'
              action: keep

# Additional Service Monitors
additionalServiceMonitors:
  - name: "kubelet"
    selector:
      matchLabels:
        app.kubernetes.io/name: kubelet
    namespaceSelector:
      any: true
    endpoints:
      - port: https-metrics
        scheme: https
        tlsConfig:
          insecureSkipVerify: true
        bearerTokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token

# Pod Monitors
additionalPodMonitors:
  - name: "core-dns"
    selector:
      matchLabels:
        k8s-app: kube-dns
    namespaceSelector:
      matchNames:
        - kube-system
    podMetricsEndpoints:
      - port: metrics
        path: /metrics

# Network policies
networkPolicy:
  enabled: false

# RBAC
rbac:
  create: true

# Service accounts
serviceAccounts:
  prometheus:
    create: true
  alertmanager:
    create: true
  nodeExporter:
    create: true
  grafana:
    create: true
EOF

    success "Custom Helm values prepared"
}

# =============================================================================
# STEP 6: Install kube-prometheus-stack
# =============================================================================

install_monitoring_stack() {
    log "Installing kube-prometheus-stack..."
    
    # Check if release already exists
    if helm status $HELM_RELEASE -n $NAMESPACE &> /dev/null; then
        warning "Helm release '$HELM_RELEASE' already exists. Upgrading..."
        helm upgrade $HELM_RELEASE prometheus-community/kube-prometheus-stack \
            --namespace $NAMESPACE \
            --values monitoring-values.yaml \
            --wait \
            --timeout 10m
    else
        log "Installing new monitoring stack..."
        helm install $HELM_RELEASE prometheus-community/kube-prometheus-stack \
            --namespace $NAMESPACE \
            --values monitoring-values.yaml \
            --wait \
            --timeout 10m
    fi
    
    success "kube-prometheus-stack installed successfully"
}

# =============================================================================
# STEP 7: Verify Installation
# =============================================================================

verify_installation() {
    log "Verifying installation..."
    
    # Wait for pods to be ready
    log "Waiting for pods to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kube-prometheus-stack-prometheus -n $NAMESPACE --timeout=300s || true
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kube-prometheus-stack-grafana -n $NAMESPACE --timeout=300s || true
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kube-prometheus-stack-alertmanager -n $NAMESPACE --timeout=300s || true
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kube-prometheus-stack-kube-state-metrics -n $NAMESPACE --timeout=300s || true
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kube-prometheus-stack-prometheus-node-exporter -n $NAMESPACE --timeout=300s || true
    
    # Check pod status
    log "Checking pod status..."
    kubectl get pods -n $NAMESPACE
    
    # Check services
    log "Checking services..."
    kubectl get services -n $NAMESPACE
    
    success "Installation verification completed"
}

# =============================================================================
# STEP 8: Get Access Information
# =============================================================================

get_access_info() {
    log "Getting access information..."
    
    # Get Minikube IP
    local minikube_ip=$(minikube ip 2>/dev/null || echo "localhost")
    
    echo ""
    echo "==============================================="
    echo "  MONITORING STACK ACCESS INFORMATION"
    echo "==============================================="
    echo ""
    echo "Grafana:"
    echo "  URL:      http://$minikube_ip:$GRAFANA_NODEPORT"
    echo "  Username: $GRAFANA_USER"
    echo "  Password: $GRAFANA_PASSWORD"
    echo ""
    echo "Prometheus:"
    echo "  Port-forward: kubectl port-forward -n $NAMESPACE svc/kube-prometheus-stack-prometheus 9090:9090"
    echo ""
    echo "AlertManager:"
    echo "  Port-forward: kubectl port-forward -n $NAMESPACE svc/kube-prometheus-stack-alertmanager 9093:9093"
    echo ""
    echo "Minikube IP: $minikube_ip"
    echo "Namespace:   $NAMESPACE"
    echo ""
    echo "==============================================="
    
    success "Access information displayed"
}

# =============================================================================
# STEP 9: Port Forward Setup (Optional)
# =============================================================================

setup_port_forward() {
    log "Setting up port forwarding (optional)..."
    
    # Function to stop port forwarding
    stop_port_forward() {
        log "Stopping port forwarding..."
        pkill -f "kubectl port-forward" || true
        exit 0
    }
    
    # Set up trap for cleanup
    trap stop_port_forward INT TERM
    
    # Start port forwarding in background
    log "Starting port forwarding for Grafana..."
    kubectl port-forward -n $NAMESPACE svc/kube-prometheus-stack-grafana $GRAFANA_NODEPORT:3000 &
    local grafana_pid=$!
    
    log "Starting port forwarding for Prometheus..."
    kubectl port-forward -n $NAMESPACE svc/kube-prometheus-stack-prometheus 9090:9090 &
    local prometheus_pid=$!
    
    log "Starting port forwarding for AlertManager..."
    kubectl port-forward -n $NAMESPACE svc/kube-prometheus-stack-alertmanager 9093:9093 &
    local alertmanager_pid=$!
    
    echo ""
    echo "Port forwarding started:"
    echo "  Grafana:     http://localhost:$GRAFANA_NODEPORT"
    echo "  Prometheus:  http://localhost:9090"
    echo "  AlertManager: http://localhost:9093"
    echo ""
    echo "Press Ctrl+C to stop port forwarding"
    
    # Wait for user interrupt
    wait
}

# =============================================================================
# STEP 10: Debugging Functions
# =============================================================================

debug_dashboard_issues() {
    log "Debugging dashboard issues..."
    
    echo "Checking Grafana configuration..."
    kubectl get configmap -n $NAMESPACE | grep grafana
    
    echo "Checking Grafana logs..."
    kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=kube-prometheus-stack-grafana --tail=50
    
    echo "Checking Grafana API..."
    local grafana_pod=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=kube-prometheus-stack-grafana -o jsonpath='{.items[0].metadata.name}')
    if [[ -n "$grafana_pod" ]]; then
        kubectl exec -n $NAMESPACE $grafana_pod -- curl -s http://localhost:3000/api/health || echo "Grafana API not accessible"
    fi
}

debug_prometheus_scraping() {
    log "Debugging Prometheus scraping issues..."
    
    echo "Checking Prometheus targets..."
    local prometheus_pod=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=kube-prometheus-stack-prometheus -o jsonpath='{.items[0].metadata.name}')
    if [[ -n "$prometheus_pod" ]]; then
        kubectl exec -n $NAMESPACE $prometheus_pod -- wget -qO- http://localhost:9090/api/v1/targets | head -20
    fi
    
    echo "Checking ServiceMonitors..."
    kubectl get servicemonitors -n $NAMESPACE -o wide
    
    echo "Checking Prometheus logs..."
    kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=kube-prometheus-stack-prometheus --tail=50
}

debug_grafana_access() {
    log "Debugging Grafana access issues..."
    
    echo "Checking Grafana service..."
    kubectl get svc -n $NAMESPACE | grep grafana
    
    echo "Checking Grafana endpoints..."
    kubectl get endpoints -n $NAMESPACE | grep grafana
    
    echo "Checking Grafana pod status..."
    kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=kube-prometheus-stack-grafana -o wide
    
    echo "Testing Grafana service connectivity..."
    local minikube_ip=$(minikube ip 2>/dev/null || echo "localhost")
    curl -I http://$minikube_ip:$GRAFANA_NODEPORT || echo "Cannot reach Grafana"
}

# =============================================================================
# STEP 11: Cleanup Function
# =============================================================================

cleanup() {
    log "Cleaning up..."
    
    # Stop port forwarding
    pkill -f "kubectl port-forward" || true
    
    # Remove temporary files
    rm -f monitoring-values.yaml
    
    success "Cleanup completed"
}

# =============================================================================
# STEP 12: Help Function
# =============================================================================

show_help() {
    cat <<EOF
Production-Grade Kubernetes Monitoring Stack Setup

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -h, --help              Show this help message
    -i, --install           Install monitoring stack
    -u, --upgrade           Upgrade existing installation
    -d, --debug             Run debugging functions
    -p, --port-forward      Setup port forwarding
    -c, --cleanup           Clean up resources
    -v, --verify            Verify installation
    --debug-dashboard       Debug dashboard issues
    --debug-prometheus      Debug Prometheus scraping
    --debug-grafana         Debug Grafana access

EXAMPLES:
    $0 --install            # Install monitoring stack
    $0 --port-forward       # Setup port forwarding
    $0 --debug-dashboard   # Debug dashboard issues
    $0 --cleanup            # Clean up everything

EOF
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    # Set up cleanup trap
    trap cleanup EXIT
    
    # Parse command line arguments
    case "${1:-}" in
        -h|--help)
            show_help
            exit 0
            ;;
        -i|--install)
            check_prerequisites
            install_helm
            add_helm_repos
            create_namespace
            prepare_values
            install_monitoring_stack
            verify_installation
            get_access_info
            ;;
        -u|--upgrade)
            check_prerequisites
            add_helm_repos
            prepare_values
            install_monitoring_stack
            verify_installation
            get_access_info
            ;;
        -d|--debug)
            debug_dashboard_issues
            debug_prometheus_scraping
            debug_grafana_access
            ;;
        -p|--port-forward)
            setup_port_forward
            ;;
        -c|--cleanup)
            log "Uninstalling monitoring stack..."
            helm uninstall $HELM_RELEASE -n $NAMESPACE || true
            kubectl delete namespace $NAMESPACE || true
            success "Cleanup completed"
            ;;
        -v|--verify)
            verify_installation
            get_access_info
            ;;
        --debug-dashboard)
            debug_dashboard_issues
            ;;
        --debug-prometheus)
            debug_prometheus_scraping
            ;;
        --debug-grafana)
            debug_grafana_access
            ;;
        "")
            # Default action - install
            check_prerequisites
            install_helm
            add_helm_repos
            create_namespace
            prepare_values
            install_monitoring_stack
            verify_installation
            get_access_info
            ;;
        *)
            error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"
