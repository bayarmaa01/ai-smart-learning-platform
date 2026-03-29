#!/bin/bash

set -euo pipefail

# =============================================================================
# 🧹 REPOSITORY CLEANUP SCRIPT
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  INFO: $1${NC}"; }
log_success() { echo -e "${GREEN}✅ SUCCESS: $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  WARNING: $1${NC}"; }
log_error() { echo -e "${RED}❌ ERROR: $1${NC}"; }

# Files to delete
OLD_SCRIPTS=(
    "test-ingress.sh"
    "start-devops.sh"
    "setup-local-cluster.sh"
    "start-dev.sh"
    "simple-fix.sh"
    "deploy-production.sh"
    "deploy-production-original.sh"
    "deploy-k8s.sh"
    "deploy-full-platform.sh"
    "check-status.sh"
    "check-pods.sh"
    "build-docker-images.sh"
    "emergency-fix.sh"
    "fix-courses.sh"
    "fix-cloudflare-tunnel.sh"
    "recover-deployment.sh"
    "deploy.sh"
    "access-services.sh"
)

OLD_YAML_FILES=(
    "ingress.yaml"
    "k8s/service-accounts.yaml"
    "k8s/secrets.yaml"
    "k8s/redis-deployment.yaml"
    "k8s/postgres-statefulset.yaml"
    "k8s/network-policy.yaml"
    "k8s/namespace.yaml"
    "k8s/monitoring-stack.yaml"
    "k8s/monitoring-config.yaml"
    "k8s/backend-deployment.yaml"
    "k8s/argocd-application.yaml"
    "k8s/ai-service-deployment.yaml"
    "k8s/configmap.yaml"
    "k8s/cert-manager.yaml"
    "k8s/eduai-secrets.yaml"
    "k8s/frontend-deployment.yaml"
)

OTHER_FILES=(
    "docker-compose.yml"
    "docker-compose.yaml"
    ".dockerignore"
    "Dockerfile.old"
    "*.backup"
    "*.bak"
    "*.tmp"
)

main() {
    echo "🧹 Repository Cleanup"
    echo "===================="
    echo ""
    
    log_info "Removing old scripts..."
    for script in "${OLD_SCRIPTS[@]}"; do
        if [ -f "$script" ]; then
            rm "$script"
            log_success "Deleted: $script"
        fi
    done
    
    log_info "Removing old YAML files..."
    for yaml in "${OLD_YAML_FILES[@]}"; do
        if [ -f "$yaml" ]; then
            rm "$yaml"
            log_success "Deleted: $yaml"
        fi
    done
    
    log_info "Removing other unnecessary files..."
    for file in "${OTHER_FILES[@]}"; do
        if ls $file 1> /dev/null 2>&1; then
            rm -f $file
            log_success "Deleted: $file"
        fi
    done
    
    log_info "Cleaning up k8s directory..."
    if [ -d "k8s" ]; then
        # Keep only essential files
        if [ -f "k8s/namespace.yaml" ]; then
            rm k8s/namespace.yaml
        fi
        # Remove directory if empty
        rmdir k8s 2>/dev/null || true
    fi
    
    log_info "Cleaning up helm directory..."
    if [ -d "helm" ]; then
        # Keep helm chart but clean up unused values files
        rm -f helm/eduai/values-staging.yaml
        rm -f helm/eduai/values-production.yaml
        log_success "Cleaned up helm directory"
    fi
    
    log_info "Removing test and coverage files..."
    find . -name "coverage" -type d -exec rm -rf {} + 2>/dev/null || true
    find . -name "*.lcov" -delete 2>/dev/null || true
    find . -name ".nyc_output" -type d -exec rm -rf {} + 2>/dev/null || true
    
    log_info "Removing temporary files..."
    find . -name "*.log" -delete 2>/dev/null || true
    find . -name "*.tmp" -delete 2>/dev/null || true
    find . -name ".DS_Store" -delete 2>/dev/null || true
    
    log_info "Cleaning up git history (optional)..."
    echo "💡 To clean up git history, run:"
    echo "   git add -A"
    echo "   git commit -m 'Clean up repository'"
    echo "   git push origin main"
    
    echo ""
    log_success "Repository cleanup completed!"
    echo ""
    echo "📁 Clean structure:"
    echo "   ├── devops.sh          # Full deployment"
    echo "   ├── run.sh             # Fast startup"
    echo "   ├── cleanup.sh         # This script"
    echo "   ├── frontend/          # Frontend app"
    echo "   ├── backend/           # Backend app"
    echo "   ├── ai-service/        # AI service (if used)"
    echo "   └── helm/              # Helm charts"
    echo ""
}

main "$@"
