#!/bin/bash

# AI Smart Learning Platform - DevOps Debug Script
# Verifies if the system is REALLY working, even if automation fails
# ALWAYS fallback to PORT-FORWARD and make app accessible via localhost
# Usage: ./devops-debug.sh

set +e  # Never crash - handle errors gracefully

# =============================================================================
# 🎨 COLOR DEFINITIONS
# =============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# =============================================================================
# 📋 CONFIGURATION
# =============================================================================
NAMESPACE="eduai"
DOMAIN="ailearn.duckdns.org"
FRONTEND_LOCAL_PORT=3000
BACKEND_LOCAL_PORT=4000
GRAFANA_LOCAL_PORT=3001
PROMETHEUS_LOCAL_PORT=9090
ARGOCD_LOCAL_PORT=18080
OLLAMA_LOCAL_PORT=11434

# Port-forward PIDs storage
PIDS_FILE="/tmp/devops-debug-pids.txt"

# =============================================================================
# 📝 LOGGING FUNCTIONS
# =============================================================================
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${PURPLE}[STEP]${NC} $1"; }
log_header() { echo -e "${WHITE}=== $1 ===${NC}"; }

# =============================================================================
# 🧹 CLEANUP FUNCTIONS
# =============================================================================
cleanup_port_forwards() {
    log_info "Cleaning up existing port forwards..."
    if [ -f "$PIDS_FILE" ]; then
        while read -r pid; do
            if kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null
                log_info "Killed process $pid"
            fi
        done < "$PIDS_FILE"
        rm -f "$PIDS_FILE"
    fi
    
    # Kill any remaining port-forward processes
    pkill -f "kubectl port-forward" 2>/dev/null || true
    pkill -f "minikube kubectl -- port-forward" 2>/dev/null || true
}

# Trap cleanup on script exit
trap cleanup_port_forwards EXIT

# =============================================================================
# 🔧 UTILITY FUNCTIONS
# =============================================================================
wait_for_service() {
    local url=$1
    local service_name=$2
    local max_attempts=30
    local attempt=1
    
    log_info "Checking $service_name at $url..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s --max-time 5 "$url" >/dev/null 2>&1; then
            log_success "$service_name is accessible"
            return 0
        fi
        
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    log_warning "$service_name not accessible after ${max_attempts} attempts"
    return 1
}

check_pod_health() {
    local pod_name=$1
    local namespace=$2
    
    local status=$(kubectl get pod "$pod_name" -n "$namespace" -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
    local restarts=$(kubectl get pod "$pod_name" -n "$namespace" -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null || echo "0")
    
    echo "$status:$restarts"
}

print_fix_suggestion() {
    local issue=$1
    local suggestion=$2
    
    echo ""
    log_warning "🔧 FIX SUGGESTION:"
    echo "   Issue: $issue"
    echo "   Fix: $suggestion"
    echo ""
}

# =============================================================================
# 🚀 MAIN DEBUG FUNCTIONS
# =============================================================================

# 1. CLUSTER SANITY CHECK
check_cluster_sanity() {
    log_header "CLUSTER CHECK"
    
    log_info "Checking kubectl configuration..."
    local current_context=$(kubectl config current-context 2>/dev/null || echo "none")
    
    if [ "$current_context" != "minikube" ]; then
        log_warning "Current context is '$current_context', switching to minikube..."
        if kubectl config use-context minikube >/dev/null 2>&1; then
            log_success "Switched to minikube context"
        else
            log_error "Failed to switch to minikube context"
            print_fix_suggestion "Minikube context not available" "Run: minikube start"
            return 1
        fi
    else
        log_success "Using correct context: minikube"
    fi
    
    log_info "Checking cluster nodes..."
    if kubectl get nodes >/dev/null 2>&1; then
        local node_count=$(kubectl get nodes --no-headers | wc -l)
        log_success "Cluster has $node_count node(s)"
        kubectl get nodes
    else
        log_error "Cannot access cluster nodes"
        print_fix_suggestion "Cluster not accessible" "Run: minikube start"
        return 1
    fi
    
    log_info "Checking Minikube status..."
    if minikube status >/dev/null 2>&1; then
        log_success "Minikube is running"
        minikube status
    else
        log_error "Minikube is not running"
        print_fix_suggestion "Minikube not running" "Run: minikube start --driver=docker"
        return 1
    fi
    
    return 0
}

# 2. NAMESPACE CHECK
check_namespace() {
    log_header "NAMESPACE CHECK"
    
    log_info "Checking namespace '$NAMESPACE'..."
    if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        log_success "Namespace '$NAMESPACE' exists"
    else
        log_error "Namespace '$NAMESPACE' does not exist"
        echo ""
        log_info "Available namespaces:"
        kubectl get namespaces
        echo ""
        print_fix_suggestion "Missing namespace" "Run: ./devops-smart.sh full"
        return 1
    fi
    
    return 0
}

# 3. POD HEALTH CHECK
check_pods() {
    log_header "POD CHECK"
    
    log_info "Checking pods in namespace '$NAMESPACE'..."
    if ! kubectl get pods -n "$NAMESPACE" >/dev/null 2>&1; then
        log_error "Cannot access pods in namespace '$NAMESPACE'"
        return 1
    fi
    
    echo ""
    kubectl get pods -n "$NAMESPACE" -o wide
    echo ""
    
    # Check each pod for issues
    local pods_with_issues=""
    
    while IFS= read -r pod_line; do
        if [ -n "$pod_line" ] && [ "$pod_line" != "NAME" ]; then
            local pod_name=$(echo "$pod_line" | awk '{print $1}')
            local pod_info=$(check_pod_health "$pod_name" "$NAMESPACE")
            local status=$(echo "$pod_info" | cut -d: -f1)
            local restarts=$(echo "$pod_info" | cut -d: -f2)
            
            case "$status" in
                "Running")
                    if [ "$restarts" -gt 0 ]; then
                        log_warning "Pod $pod_name has restarted $restarts times"
                        pods_with_issues="$pods_with_issues $pod_name"
                    else
                        log_success "Pod $pod_name is healthy"
                    fi
                    ;;
                "CrashLoopBackOff"|"Error"|"Failed")
                    log_error "Pod $pod_name is in $status state"
                    pods_with_issues="$pods_with_issues $pod_name"
                    ;;
                "Pending")
                    log_warning "Pod $pod_name is pending"
                    pods_with_issues="$pods_with_issues $pod_name"
                    ;;
                "NotFound")
                    log_error "Pod $pod_name not found"
                    ;;
                *)
                    log_warning "Pod $pod_name status: $status"
                    ;;
            esac
        fi
    done <<< "$(kubectl get pods -n "$NAMESPACE" --no-headers)"
    
    # Show logs for problematic pods
    if [ -n "$pods_with_issues" ]; then
        echo ""
        log_warning "🔍 ANALYZING PROBLEMATIC PODS:"
        for pod in $pods_with_issues; do
            echo ""
            log_info "Logs for pod $pod (last 15 lines):"
            echo "----------------------------------------"
            kubectl logs "$pod" -n "$NAMESPACE" --tail=15 2>/dev/null || echo "Could not fetch logs"
            echo "----------------------------------------"
        done
    fi
    
    return 0
}

# 4. SERVICE CHECK
check_services() {
    log_header "SERVICE CHECK"
    
    log_info "Checking services in namespace '$NAMESPACE'..."
    if ! kubectl get services -n "$NAMESPACE" >/dev/null 2>&1; then
        log_error "Cannot access services in namespace '$NAMESPACE'"
        return 1
    fi
    
    echo ""
    kubectl get services -n "$NAMESPACE"
    echo ""
    
    # Check NodePorts
    log_info "Analyzing NodePort services..."
    local nodeport_services=$(kubectl get services -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}:{.spec.type}:{.spec.ports[0].nodePort}{"\n"}{end}' 2>/dev/null || echo "")
    
    if [ -n "$nodeport_services" ]; then
        while IFS= read -r service_info; do
            if [ -n "$service_info" ]; then
                local service_name=$(echo "$service_info" | cut -d: -f1)
                local service_type=$(echo "$service_info" | cut -d: -f2)
                local nodeport=$(echo "$service_info" | cut -d: -f3)
                
                if [ "$service_type" = "NodePort" ] && [ -n "$nodeport" ]; then
                    log_info "Service $service_name: NodePort $nodeport"
                fi
            fi
        done <<< "$nodeport_services"
        
        echo ""
        log_warning "⚠️  WSL2 NODEPORT LIMITATION:"
        log_warning "NodePort services may not work in WSL2 due to network isolation"
        log_warning "This script will use port-forwarding as fallback"
        echo ""
    fi
    
    return 0
}

# 5. PORT-FORWARD MODE (MOST IMPORTANT)
setup_port_forwards() {
    log_header "PORT FORWARD"
    
    log_info "Setting up port forwarding to localhost..."
    
    # Clean up existing port forwards
    cleanup_port_forwards
    
    # Get Minikube IP for reference
    local minikube_ip=$(minikube ip 2>/dev/null || echo "192.168.49.2")
    
    # Start port forwards in background
    log_info "Starting port forwarding services..."
    
    # Frontend port-forward
    if kubectl get service frontend -n "$NAMESPACE" >/dev/null 2>&1; then
        log_info "Forwarding frontend service..."
        kubectl port-forward -n "$NAMESPACE" svc/frontend "$FRONTEND_LOCAL_PORT:3000" >/dev/null 2>&1 &
        local frontend_pid=$!
        echo "$frontend_pid" >> "$PIDS_FILE"
        log_success "Frontend port-forward started (PID: $frontend_pid)"
    else
        log_warning "Frontend service not found"
    fi
    
    # Backend port-forward
    if kubectl get service backend -n "$NAMESPACE" >/dev/null 2>&1; then
        log_info "Forwarding backend service..."
        kubectl port-forward -n "$NAMESPACE" svc/backend "$BACKEND_LOCAL_PORT:5000" >/dev/null 2>&1 &
        local backend_pid=$!
        echo "$backend_pid" >> "$PIDS_FILE"
        log_success "Backend port-forward started (PID: $backend_pid)"
    else
        log_warning "Backend service not found"
    fi
    
    # Grafana port-forward
    if kubectl get service grafana -n monitoring >/dev/null 2>&1; then
        log_info "Forwarding Grafana service..."
        kubectl port-forward -n monitoring svc/grafana "$GRAFANA_LOCAL_PORT:3000" >/dev/null 2>&1 &
        local grafana_pid=$!
        echo "$grafana_pid" >> "$PIDS_FILE"
        log_success "Grafana port-forward started (PID: $grafana_pid)"
    else
        log_warning "Grafana service not found"
    fi
    
    # Prometheus port-forward
    if kubectl get service prometheus-server -n monitoring >/dev/null 2>&1; then
        log_info "Forwarding Prometheus service..."
        kubectl port-forward -n monitoring svc/prometheus-server "$PROMETHEUS_LOCAL_PORT:9090" >/dev/null 2>&1 &
        local prometheus_pid=$!
        echo "$prometheus_pid" >> "$PIDS_FILE"
        log_success "Prometheus port-forward started (PID: $prometheus_pid)"
    else
        log_warning "Prometheus service not found"
    fi
    
    # ArgoCD port-forward
    if kubectl get service argocd-server -n argocd >/dev/null 2>&1; then
        log_info "Forwarding ArgoCD service..."
        kubectl port-forward -n argocd svc/argocd-server "$ARGOCD_LOCAL_PORT:80" >/dev/null 2>&1 &
        local argocd_pid=$!
        echo "$argocd_pid" >> "$PIDS_FILE"
        log_success "ArgoCD port-forward started (PID: $argocd_pid)"
    else
        log_warning "ArgoCD service not found"
    fi
    
    # Wait a moment for port forwards to establish
    sleep 3
    
    echo ""
    log_header "🚀 ACCESS URLS (LOCALHOST)"
    log_success "✅ Frontend:    http://localhost:$FRONTEND_LOCAL_PORT"
    log_success "✅ Backend:     http://localhost:$BACKEND_LOCAL_PORT"
    log_success "✅ Grafana:     http://localhost:$GRAFANA_LOCAL_PORT"
    log_success "✅ Prometheus:  http://localhost:$PROMETHEUS_LOCAL_PORT"
    log_success "✅ ArgoCD:      http://localhost:$ARGOCD_LOCAL_PORT"
    echo ""
    
    return 0
}

# 6. API TEST
test_api() {
    log_header "API TEST"
    
    log_info "Testing backend API health endpoint..."
    
    # Wait a moment for services to be ready
    sleep 2
    
    if curl -s --max-time 10 "http://localhost:$BACKEND_LOCAL_PORT/health" >/dev/null 2>&1; then
        log_success "Backend health endpoint is accessible"
        
        # Get actual response
        local health_response=$(curl -s "http://localhost:$BACKEND_LOCAL_PORT/health" 2>/dev/null || echo "No response")
        log_info "Health response: $health_response"
    else
        log_error "Backend health endpoint not accessible"
        print_fix_suggestion "Backend not responding" "Check backend pod logs: kubectl logs -n $NAMESPACE -l app=backend"
    fi
    
    return 0
}

# 7. AI TEST
test_ai_endpoint() {
    log_header "AI TEST"
    
    log_info "Testing AI endpoint..."
    
    # Try common AI endpoints
    local ai_endpoints="/api/ai /ai /api/chat /chat"
    local working_endpoint=""
    
    for endpoint in $ai_endpoints; do
        log_info "Testing endpoint: $endpoint"
        if curl -s --max-time 10 "http://localhost:$BACKEND_LOCAL_PORT$endpoint" >/dev/null 2>&1; then
            working_endpoint="$endpoint"
            break
        fi
    done
    
    if [ -n "$working_endpoint" ]; then
        log_success "AI endpoint found: $working_endpoint"
        local ai_response=$(curl -s "http://localhost:$BACKEND_LOCAL_PORT$working_endpoint" 2>/dev/null | head -c 200)
        log_info "AI response sample: $ai_response..."
    else
        log_warning "No AI endpoint found or accessible"
        print_fix_suggestion "AI endpoint not working" "Check AI service configuration and Ollama connection"
    fi
    
    return 0
}

# 8. OLLAMA CHECK
check_ollama() {
    log_header "OLLAMA CHECK"
    
    log_info "Checking Ollama service..."
    
    # Check if Ollama is running locally
    if curl -s --max-time 5 "http://localhost:$OLLAMA_LOCAL_PORT/api/tags" >/dev/null 2>&1; then
        log_success "Ollama service is accessible"
        
        # Check for gemma:2b model
        local models=$(curl -s "http://localhost:$OLLAMA_LOCAL_PORT/api/tags" 2>/dev/null | grep -o '"gemma:2b"' || echo "")
        
        if [ -n "$models" ]; then
            log_success "Model 'gemma:2b' is available"
        else
            log_warning "Model 'gemma:2b' not found"
            print_fix_suggestion "Missing AI model" "Run: ollama pull gemma:2b"
        fi
        
        # List available models
        log_info "Available models:"
        curl -s "http://localhost:$OLLAMA_LOCAL_PORT/api/tags" 2>/dev/null | grep -o '"name":"[^"]*"' | sed 's/"name":"//g' | sed 's/"//g' | head -5
    else
        log_warning "Ollama service not accessible"
        print_fix_suggestion "Ollama not running" "Run: ollama serve"
    fi
    
    return 0
}

# 9. PROMETHEUS CHECK
check_prometheus() {
    log_header "PROMETHEUS CHECK"
    
    log_info "Checking Prometheus service..."
    
    if wait_for_service "http://localhost:$PROMETHEUS_LOCAL_PORT" "Prometheus"; then
        log_success "Prometheus UI is accessible"
        
        # Check targets
        log_info "Checking Prometheus targets..."
        local targets_response=$(curl -s "http://localhost:$PROMETHEUS_LOCAL_PORT/api/v1/targets" 2>/dev/null || echo "")
        
        if echo "$targets_response" | grep -q "active"; then
            local active_targets=$(echo "$targets_response" | grep -o '"health":"up"' | wc -l)
            log_success "Found $active_targets healthy targets"
        else
            log_warning "Could not retrieve Prometheus targets"
        fi
    else
        log_error "Prometheus not accessible"
        print_fix_suggestion "Prometheus down" "Check monitoring namespace: kubectl get pods -n monitoring"
    fi
    
    return 0
}

# 10. GRAFANA AUTO DASHBOARD
setup_grafana_info() {
    log_header "GRAFANA DASHBOARD INFO"
    
    log_info "Grafana dashboard setup information..."
    
    if wait_for_service "http://localhost:$GRAFANA_LOCAL_PORT" "Grafana"; then
        log_success "Grafana UI is accessible"
        
        echo ""
        log_info "🔧 GRAFANA SETUP:"
        log_info "   URL: http://localhost:$GRAFANA_LOCAL_PORT"
        log_info "   Default credentials: admin/admin"
        echo ""
        
        log_info "📊 AUTO-DASHBOARD SETUP:"
        log_info "   1. Login with admin/admin"
        log_info "   2. Add Prometheus data source:"
        log_info "      URL: http://prometheus-server:9090"
        log_info "      Access: Server (default)"
        echo ""
        
        log_info "🎯 RECOMMENDED DASHBOARDS:"
        log_info "   • Kubernetes Overview"
        log_info "   • Node Exporter Full"
        log_info "   • Pod Health"
        log_info "   • Application Metrics"
        echo ""
        
        log_info "🚀 PROVISIONING (Auto-setup):"
        log_info "   To auto-load dashboards, add provisioning configs:"
        log_info "   /etc/grafana/provisioning/datasources/prometheus.yml"
        log_info "   /etc/grafana/provisioning/dashboards/k8s.yml"
    else
        log_error "Grafana not accessible"
        print_fix_suggestion "Grafana down" "Check monitoring namespace: kubectl get pods -n monitoring"
    fi
    
    return 0
}

# =============================================================================
# 🎯 MAIN EXECUTION
# =============================================================================
main() {
    echo ""
    log_header "🔍 AI SMART LEARNING PLATFORM - DEBUG SCRIPT"
    log_info "This script verifies if system is REALLY working"
    log_info "Always uses port-forwarding for reliable localhost access"
    echo ""
    
    # Execute all checks
    check_cluster_sanity
    local cluster_status=$?
    
    check_namespace
    local namespace_status=$?
    
    if [ $cluster_status -eq 0 ] && [ $namespace_status -eq 0 ]; then
        check_pods
        check_services
        setup_port_forwards
        test_api
        test_ai_endpoint
        check_ollama
        check_prometheus
        setup_grafana_info
    else
        log_error "Critical issues found - cannot proceed with full checks"
        log_info "Please fix the cluster/namespace issues first"
    fi
    
    echo ""
    log_header "🏁 DEBUG COMPLETE"
    log_info "Port forwarding will remain active"
    log_info "Press Ctrl+C to stop all port forwards"
    echo ""
    
    # Keep script running to maintain port forwards
    log_info "Monitoring port forwarding status..."
    while true; do
        sleep 30
        # Check if port forwards are still running
        if [ -f "$PIDS_FILE" ]; then
            local active_count=0
            while read -r pid; do
                if kill -0 "$pid" 2>/dev/null; then
                    active_count=$((active_count + 1))
                fi
            done < "$PIDS_FILE"
            
            if [ $active_count -eq 0 ]; then
                log_warning "All port forwards have stopped"
                break
            fi
        else
            log_warning "No port forwards found"
            break
        fi
    done
}

# Execute main function
main "$@"
