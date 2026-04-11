#!/bin/bash

# =============================================================================
# AI Smart Learning Platform - DEBUG & VERIFICATION SCRIPT
# =============================================================================
# This script VERIFIES if your app is ACTUALLY working, even if DevOps automation fails
# Author: Senior DevOps Engineer
# Version: 1.0
# =============================================================================

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
FRONTEND_NODEPORT=30007
BACKEND_NODEPORT=30008
LOCAL_FRONTEND_PORT=3000
LOCAL_BACKEND_PORT=5000

# Global variables
MINIKUBE_IP=""
PORT_FORWARD_PIDS=()

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${PURPLE}[STEP]${NC} $1"; }
log_critical() { echo -e "${RED}[CRITICAL]${NC} $1"; }

# Cleanup function
cleanup() {
    log_info "Cleaning up port-forward processes..."
    for pid in "${PORT_FORWARD_PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
        fi
    done
}

# Trap cleanup on exit
trap cleanup EXIT

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Wait for service to be ready
wait_for_service() {
    local url="$1"
    local timeout="${2:-30}"
    local count=0
    
    while [ $count -lt $timeout ]; do
        if curl -s --max-time 3 "$url" >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
        count=$((count + 1))
    done
    return 1
}

# Test endpoint with detailed output
test_endpoint() {
    local url="$1"
    local description="$2"
    local timeout="${3:-10}"
    
    echo -n "Testing $description... "
    if curl -s --max-time "$timeout" -w "HTTP %{http_code}" "$url" 2>/dev/null | tail -n1; then
        echo " $(log_success "WORKING")"
        return 0
    else
        echo " $(log_error "FAILED")"
        return 1
    fi
}

# =============================================================================
# STEP 1: CLUSTER SANITY CHECK
# =============================================================================

check_cluster_sanity() {
    log_step "1. CLUSTER SANITY CHECK"
    echo "=================================="
    
    # Check kubectl context
    log_info "Checking kubectl context..."
    local current_context=$(kubectl config current-context 2>/dev/null || echo "UNKNOWN")
    echo "Current context: $current_context"
    
    if [[ "$current_context" != "minikube" ]]; then
        log_warning "Context is not 'minikube'. Attempting to fix..."
        if kubectl config use-context minikube 2>/dev/null; then
            log_success "Switched to minikube context"
        else
            log_error "Cannot switch to minikube context"
            echo "Fix: Run 'minikube start' first"
        fi
    fi
    
    # Check nodes
    log_info "Checking cluster nodes..."
    if kubectl get nodes >/dev/null 2>&1; then
        local nodes=$(kubectl get nodes --no-headers | wc -l)
        log_success "Found $nodes node(s)"
        kubectl get nodes
    else
        log_error "Cannot connect to cluster"
        echo "Fix: Run 'minikube start'"
        return 1
    fi
    
    # Check Minikube status
    log_info "Checking Minikube status..."
    if command_exists minikube; then
        if minikube status >/dev/null 2>&1; then
            log_success "Minikube is running"
            MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "")
            echo "Minikube IP: $MINIKUBE_IP"
        else
            log_error "Minikube is not running"
            echo "Fix: Run 'minikube start'"
            return 1
        fi
    else
        log_error "Minikube command not found"
        echo "Fix: Install Minikube first"
        return 1
    fi
    
    echo ""
    return 0
}

# =============================================================================
# STEP 2: NAMESPACE RECOVERY
# =============================================================================

check_namespace() {
    log_step "2. NAMESPACE RECOVERY"
    echo "=================================="
    
    log_info "Checking namespace: $NAMESPACE"
    
    # List all namespaces
    echo "Available namespaces:"
    kubectl get namespaces
    
    # Check if eduai exists
    if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        log_success "Namespace '$NAMESPACE' exists"
        kubectl get namespace "$NAMESPACE"
    else
        log_critical "Namespace '$NAMESPACE' NOT FOUND!"
        echo ""
        echo "CRITICAL: The eduai namespace is missing!"
        echo ""
        echo "POSSIBLE CAUSES:"
        echo "  1. Deployment script failed halfway"
        echo "  2. Someone deleted the namespace"
        echo "  3. Cluster was reset"
        echo ""
        echo "FIX OPTIONS:"
        echo "  1. Re-run deployment: ./devops-smart.sh full"
        echo "  2. Or recreate manually:"
        echo "     kubectl create namespace $NAMESPACE"
        echo ""
        return 1
    fi
    
    echo ""
    return 0
}

# =============================================================================
# STEP 3: POD HEALTH CHECK
# =============================================================================

check_pods() {
    log_step "3. POD HEALTH CHECK"
    echo "=================================="
    
    log_info "Checking pods in namespace: $NAMESPACE"
    
    # Get pods with detailed status
    if kubectl get pods -n "$NAMESPACE" >/dev/null 2>&1; then
        echo "Pod Status:"
        kubectl get pods -n "$NAMESPACE" -o wide
        
        echo ""
        log_info "Detailed pod analysis:"
        
        # Check each pod
        local pods=$(kubectl get pods -n "$NAMESPACE" --no-headers -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,RESTARTS:.status.restartCount)
        
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                local pod_name=$(echo "$line" | awk '{print $1}')
                local status=$(echo "$line" | awk '{print $2}')
                local restarts=$(echo "$line" | awk '{print $3}')
                
                echo -n "Pod $pod_name: "
                
                case "$status" in
                    "Running")
                        if [[ "$restarts" -gt 5 ]]; then
                            echo "$(log_warning "Running but restarted $restarts times")"
                            echo "  Suggestion: Check logs with 'kubectl logs -n $NAMESPACE $pod_name'"
                        else
                            echo "$(log_success "Healthy")"
                        fi
                        ;;
                    "CrashLoopBackOff")
                        echo "$(log_error "CrashLoopBackOff - restarted $restarts times")"
                        echo "  DEBUG: Showing recent logs..."
                        kubectl logs -n "$NAMESPACE" "$pod_name" --tail=10 2>/dev/null | sed 's/^/    /'
                        ;;
                    "Pending")
                        echo "$(log_warning "Pending - check resources")"
                        echo "  DEBUG: Events:"
                        kubectl describe pod -n "$NAMESPACE" "$pod_name" 2>/dev/null | grep -A 10 "Events:" | sed 's/^/    /'
                        ;;
                    "Failed")
                        echo "$(log_error "Failed")"
                        echo "  DEBUG: Logs:"
                        kubectl logs -n "$NAMESPACE" "$pod_name" --tail=10 2>/dev/null | sed 's/^/    /'
                        ;;
                    *)
                        echo "$(log_warning "Unknown status: $status")"
                        ;;
                esac
            fi
        done <<< "$pods"
        
    else
        log_error "Cannot get pods in namespace $NAMESPACE"
        echo "Fix: Ensure namespace exists: kubectl get namespace $NAMESPACE"
        return 1
    fi
    
    echo ""
    return 0
}

# =============================================================================
# STEP 4: SERVICE CHECK
# =============================================================================

check_services() {
    log_step "4. SERVICE CHECK"
    echo "=================================="
    
    log_info "Checking services in namespace: $NAMESPACE"
    
    if kubectl get services -n "$NAMESPACE" >/dev/null 2>&1; then
        echo "Services:"
        kubectl get services -n "$NAMESPACE"
        
        echo ""
        log_info "Service analysis:"
        
        # Check NodePort services
        local nodeport_services=$(kubectl get services -n "$NAMESPACE" --no-headers -o custom-columns=NAME:.metadata.name,TYPE:.spec.type,PORT:.spec.ports[0].port,NODEPORT:.spec.ports[0].nodePort)
        
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                local svc_name=$(echo "$line" | awk '{print $1}')
                local svc_type=$(echo "$line" | awk '{print $2}')
                local port=$(echo "$line" | awk '{print $3}')
                local nodeport=$(echo "$line" | awk '{print $4}')
                
                echo -n "Service $svc_name: "
                
                if [[ "$svc_type" == "NodePort" ]]; then
                    if [[ -n "$nodeport" && "$nodeport" != "<none>" ]]; then
                        echo "$(log_success "NodePort $nodeport -> $port")"
                        echo "  URL: http://$MINIKUBE_IP:$nodeport"
                    else
                        echo "$(log_warning "NodePort but no nodePort assigned")"
                    fi
                else
                    echo "$(log_info "$svc_type on port $port")"
                fi
            fi
        done <<< "$nodeport_services"
        
    else
        log_error "Cannot get services in namespace $NAMESPACE"
        return 1
    fi
    
    echo ""
    return 0
}

# =============================================================================
# STEP 5: PORT-FORWARD FALLBACK (CRITICAL)
# =============================================================================

setup_port_forward() {
    log_step "5. PORT-FORWARD FALLBACK (CRITICAL)"
    echo "=================================="
    
    log_info "Setting up port-forward for reliable access..."
    log_warning "NodePort often fails in WSL2/Docker environments"
    log_info "Port-forward is the MOST RELIABLE method for testing"
    
    # Kill existing port-forwards
    pkill -f "kubectl port-forward" || true
    sleep 2
    
    local success_count=0
    
    # Frontend port-forward
    log_info "Setting up frontend port-forward..."
    if kubectl get service frontend -n "$NAMESPACE" >/dev/null 2>&1; then
        kubectl port-forward -n "$NAMESPACE" service/frontend "$LOCAL_FRONTEND_PORT:80" >/dev/null 2>&1 &
        local pf_pid=$!
        PORT_FORWARD_PIDS+=($pf_pid)
        
        sleep 3
        if kill -0 "$pf_pid" 2>/dev/null; then
            log_success "Frontend port-forward started (PID: $pf_pid)"
            echo "  Local URL: http://localhost:$LOCAL_FRONTEND_PORT"
            success_count=$((success_count + 1))
        else
            log_error "Frontend port-forward failed"
        fi
    else
        log_error "Frontend service not found"
    fi
    
    # Backend port-forward
    log_info "Setting up backend port-forward..."
    if kubectl get service backend -n "$NAMESPACE" >/dev/null 2>&1; then
        kubectl port-forward -n "$NAMESPACE" service/backend "$LOCAL_BACKEND_PORT:5000" >/dev/null 2>&1 &
        local pf_pid=$!
        PORT_FORWARD_PIDS+=($pf_pid)
        
        sleep 3
        if kill -0 "$pf_pid" 2>/dev/null; then
            log_success "Backend port-forward started (PID: $pf_pid)"
            echo "  Local URL: http://localhost:$LOCAL_BACKEND_PORT"
            success_count=$((success_count + 1))
        else
            log_error "Backend port-forward failed"
        fi
    else
        log_error "Backend service not found"
    fi
    
    echo ""
    if [[ $success_count -gt 0 ]]; then
        log_success "Port-forward setup complete!"
        echo ""
        echo "================================================================"
        echo "                    ACCESS URLs (WORKING)"
        echo "================================================================"
        echo "  Frontend: http://localhost:$LOCAL_FRONTEND_PORT"
        echo "  Backend:  http://localhost:$LOCAL_BACKEND_PORT"
        echo "================================================================"
        echo ""
        echo "These URLs should work EVEN if NodePort fails!"
        echo "Keep this terminal open to maintain port-forward connections."
    else
        log_error "No port-forward could be established"
        return 1
    fi
    
    echo ""
    return 0
}

# =============================================================================
# STEP 6: API HEALTH TEST
# =============================================================================

test_api_health() {
    log_step "6. API HEALTH TEST"
    echo "=================================="
    
    log_info "Testing API endpoints..."
    
    # Test backend health
    if test_endpoint "http://localhost:$LOCAL_BACKEND_PORT/health" "Backend Health"; then
        log_success "Backend health endpoint working"
        
        # Try to get actual health data
        echo "Health response:"
        curl -s "http://localhost:$LOCAL_BACKEND_PORT/health" 2>/dev/null | head -5 | sed 's/^/  /'
    else
        log_warning "Backend health endpoint not accessible"
        echo "Trying root endpoint..."
        if test_endpoint "http://localhost:$LOCAL_BACKEND_PORT/" "Backend Root"; then
            log_success "Backend root endpoint working"
        fi
    fi
    
    echo ""
    
    # Test frontend
    if test_endpoint "http://localhost:$LOCAL_FRONTEND_PORT/" "Frontend"; then
        log_success "Frontend is accessible"
    else
        log_warning "Frontend not accessible"
    fi
    
    echo ""
    return 0
}

# =============================================================================
# STEP 7: AI SERVICE TEST
# =============================================================================

test_ai_service() {
    log_step "7. AI SERVICE TEST"
    echo "=================================="
    
    log_info "Testing AI service endpoints..."
    
    # Test AI endpoint (common patterns)
    local ai_endpoints=(
        "/api/ai/chat"
        "/api/ai/test"
        "/ai/chat"
        "/api/chat"
        "/chat"
    )
    
    local found_ai=false
    
    for endpoint in "${ai_endpoints[@]}"; do
        if test_endpoint "http://localhost:$LOCAL_BACKEND_PORT$endpoint" "AI Endpoint $endpoint"; then
            log_success "AI endpoint found: $endpoint"
            found_ai=true
            
            # Try to get sample response
            echo "Sample AI response:"
            curl -s -X POST "http://localhost:$LOCAL_BACKEND_PORT$endpoint" \
                -H "Content-Type: application/json" \
                -d '{"message":"test"}' 2>/dev/null | head -3 | sed 's/^/  /'
            break
        fi
    done
    
    if ! $found_ai; then
        log_warning "No AI endpoint found. Available endpoints:"
        # Try to discover endpoints
        curl -s "http://localhost:$LOCAL_BACKEND_PORT/" 2>/dev/null | grep -o 'href="[^"]*"' | sed 's/href="/  /g' | sed 's/"//g' | head -5
    fi
    
    echo ""
    return 0
}

# =============================================================================
# STEP 8: OLLAMA CHECK
# =============================================================================

check_ollama() {
    log_step "8. OLLAMA CHECK"
    echo "=================================="
    
    log_info "Checking Ollama service..."
    
    # Check if Ollama is running locally
    if test_endpoint "http://localhost:11434/api/tags" "Ollama API"; then
        log_success "Ollama is running"
        
        echo "Available models:"
        curl -s "http://localhost:11434/api/tags" 2>/dev/null | grep -o '"name":"[^"]*"' | sed 's/"name":"/- /g' | sed 's/"//g'
        
        # Check for gemma:2b specifically
        if curl -s "http://localhost:11434/api/tags" 2>/dev/null | grep -q "gemma:2b"; then
            log_success "gemma:2b model found"
        else
            log_warning "gemma:2b model not found"
            echo "To install: ollama pull gemma:2b"
        fi
    else
        log_warning "Ollama not accessible on localhost:11434"
        echo "Suggestion: Install Ollama or check if it's running"
        echo "Install: curl -fsSL https://ollama.ai/install.sh | sh"
    fi
    
    echo ""
    return 0
}

# =============================================================================
# STEP 9: FINAL SUMMARY
# =============================================================================

print_summary() {
    log_step "9. FINAL SUMMARY"
    echo "=================================="
    
    echo "================================================================"
    echo "                    DEBUG SUMMARY"
    echo "================================================================"
    
    # Cluster status
    echo "Cluster Status:"
    if kubectl cluster-info >/dev/null 2>&1; then
        echo "  $(log_success "Connected")"
    else
        echo "  $(log_error "Disconnected")"
    fi
    
    # Namespace status
    if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        echo "  Namespace $NAMESPACE: $(log_success "Exists")"
    else
        echo "  Namespace $NAMESPACE: $(log_error "Missing")"
    fi
    
    # Pod status
    local pod_count=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
    local healthy_pods=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | grep "Running" | wc -l)
    echo "  Pods: $healthy_pods/$pod_count healthy"
    
    # Service status
    local svc_count=$(kubectl get services -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
    echo "  Services: $svc_count found"
    
    # Port-forward status
    local active_pf=0
    for pid in "${PORT_FORWARD_PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            active_pf=$((active_pf + 1))
        fi
    done
    echo "  Port-forwards: $active_pf active"
    
    echo ""
    echo "================================================================"
    echo "                    WORKING URLs"
    echo "================================================================"
    echo "  Frontend: http://localhost:$LOCAL_FRONTEND_PORT"
    echo "  Backend:  http://localhost:$LOCAL_BACKEND_PORT"
    
    if [[ -n "$MINIKUBE_IP" ]]; then
        echo ""
        echo "NodePort URLs (may not work in WSL2):"
        echo "  Frontend: http://$MINIKUBE_IP:$FRONTEND_NODEPORT"
        echo "  Backend:  http://$MINIKUBE_IP:$BACKEND_NODEPORT"
    fi
    
    echo ""
    echo "================================================================"
    echo "                    TROUBLESHOOTING TIPS"
    echo "================================================================"
    echo "1. If port-forward URLs work but NodePort URLs don't:"
    echo "   - This is NORMAL in WSL2/Docker Desktop environments"
    echo "   - Use port-forward URLs for development"
    echo ""
    echo "2. If namespace is missing:"
    echo "   - Re-run: ./devops-smart.sh full"
    echo ""
    echo "3. If pods are CrashLoopBackOff:"
    echo "   - Check logs: kubectl logs -n $NAMESPACE <pod-name>"
    echo "   - Check resources: minikube ssh 'df -h'"
    echo ""
    echo "4. If nothing works:"
    echo "   - Restart Minikube: minikube stop && minikube start"
    echo "   - Redeploy: ./devops-smart.sh full"
    echo ""
    echo "5. To keep port-forwards running in background:"
    echo "   - Run this script in a separate terminal"
    echo "   - Or use 'nohup ./devops-debug.sh > debug.log 2>&1 &'"
    echo "================================================================"
}

# =============================================================================
# MAIN FUNCTION
# =============================================================================

main() {
    echo "================================================================"
    echo "    AI Smart Learning Platform - DEBUG & VERIFICATION"
    echo "================================================================"
    echo ""
    
    # Run all checks
    local exit_code=0
    
    check_cluster_sanity || exit_code=1
    check_namespace || exit_code=1
    check_pods || exit_code=1
    check_services || exit_code=1
    
    # Critical port-forward setup
    if setup_port_forward; then
        test_api_health || exit_code=1
        test_ai_service || exit_code=1
        check_ollama || exit_code=1
    else
        exit_code=1
    fi
    
    print_summary
    
    if [[ $exit_code -eq 0 ]]; then
        log_success "Debug completed successfully!"
        echo "Your app should be accessible via the URLs above."
    else
        log_error "Some issues found. See summary above for fixes."
    fi
    
    echo ""
    log_info "Press Ctrl+C to stop port-forwards, or keep this terminal open"
    
    # Keep script running to maintain port-forwards
    if [[ ${#PORT_FORWARD_PIDS[@]} -gt 0 ]]; then
        echo "Maintaining port-forward connections..."
        wait
    fi
    
    return $exit_code
}

# =============================================================================
# SCRIPT ENTRY POINT
# =============================================================================

# Check if running in correct directory
if [[ ! -f "devops-smart.sh" ]]; then
    log_error "Please run this script from the project root directory"
    echo "Expected to find 'devops-smart.sh' in current directory"
    exit 1
fi

# Run main function
main "$@"
