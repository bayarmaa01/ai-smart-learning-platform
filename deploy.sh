#!/bin/bash

# AI Smart Learning Platform - Automatic Deployment Script
# Deploys complete platform to Kubernetes with DuckDNS domain

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="eduai"
MONITORING_NAMESPACE="monitoring"
DOMAIN="ailearn.duckdns.org"
CLUSTER_NAME="ailearn-cluster"
DOCKER_USERNAME="bayarmaa"

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

log_command() {
    echo -e "${CYAN}[CMD]${NC} $1"
}

# ASCII Art Banner
show_banner() {
    echo -e "${CYAN}"
    cat << "EOF"
    ____        __          __   _                 
   / __ \____  / /_  ____ _ / /  (_)___  ____ _ 
  / /_/ / __ \/ __ \/ __ `// /  / / __ \/ __ `/
 / ____/ /_/ / / / / /_/ // /__/ / / / / /_/ /  
/_/    \____/_/ /_/\__,_//____/_/_/ /_/\__,_/   
                                                   
    AI Smart Learning Platform - Auto Deployment
    Domain: ailearn.duckdns.org
EOF
    echo -e "${NC}"
}

check_prerequisites() {
    log_step "Checking prerequisites..."
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed. Please install kubectl first."
        echo "Install: https://kubernetes.io/docs/tasks/tools/"
        exit 1
    fi
    
    # Check if helm is installed
    if ! command -v helm &> /dev/null; then
        log_error "helm is not installed. Please install helm first."
        echo "Install: https://helm.sh/docs/intro/install/"
        exit 1
    fi
    
    # Check if minikube is installed
    if ! command -v minikube &> /dev/null; then
        log_error "minikube is not installed. Please install minikube first."
        echo "Install: https://minikube.sigs.k8s.io/docs/start/"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

start_minikube_cluster() {
    log_step "Starting Minikube cluster..."
    
    # Check if minikube is already running
    if minikube status | grep -q "Running"; then
        log_warning "Minikube cluster is already running"
    else
        log_command "minikube start --name $CLUSTER_NAME --cpus=4 --memory=8192 --disk-size=50g --kubernetes-version=v1.28.0"
        minikube start \
            --name $CLUSTER_NAME \
            --cpus=4 \
            --memory=8192 \
            --disk-size=50g \
            --kubernetes-version=v1.28.0
        
        log_success "Minikube cluster started"
    fi
    
    # Enable required addons
    log_command "minikube addons enable ingress"
    minikube addons enable ingress
    minikube addons enable metrics-server
    
    log_success "Minikube addons enabled"
}

create_namespaces() {
    log_step "Creating namespaces..."
    
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace $MONITORING_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    log_success "Namespaces created"
}

apply_secrets_and_configmaps() {
    log_step "Applying Secrets and ConfigMaps..."
    
    # Apply secrets
    if [ -f "k8s/eduai-secrets.yaml" ]; then
        log_command "kubectl apply -f k8s/eduai-secrets.yaml"
        kubectl apply -f k8s/eduai-secrets.yaml
    else
        log_warning "eduai-secrets.yaml not found, creating default secrets..."
        create_default_secrets
    fi
    
    # Apply configmaps
    if [ -f "k8s/configmap.yaml" ]; then
        log_command "kubectl apply -f k8s/configmap.yaml"
        kubectl apply -f k8s/configmap.yaml
    else
        log_warning "configmap.yaml not found, creating default configmap..."
        create_default_configmap
    fi
    
    log_success "Secrets and ConfigMaps applied"
}

create_default_secrets() {
    log_info "Creating default secrets with base64 encoded values..."
    
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: eduai-secrets
  namespace: eduai
type: Opaque
data:
  DB_PASSWORD: ZWR1YWlfZGIxMjM=
  REDIS_PASSWORD: cmVkaXMxMjM=
  JWT_SECRET: bXlzZWNyZXRrZXkxMjM=
  JWT_REFRESH_SECRET: bXlzZWNyZXRrZXlyZWZyZXNoMTIz
  OPENAI_API_KEY: c2stcHJvamVjdDEyMw==
  AI_SERVICE_API_KEY: YWktc2VydmljZS1rZXkxMjM=
EOF
}

create_default_configmap() {
    log_info "Creating default ConfigMap..."
    
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: eduai-config
  namespace: eduai
data:
  NODE_ENV: "production"
  PORT: "5000"
  DB_HOST: "postgres-service"
  DB_PORT: "5432"
  DB_NAME: "eduai_db"
  DB_USER: "postgres"
  REDIS_URL: "redis://redis-service:6379"
  AI_SERVICE_URL: "http://ai-service:8000"
  LOG_LEVEL: "info"
  ALLOWED_ORIGINS: "https://ailearn.duckdns.org"
EOF
}

deploy_postgresql() {
    log_step "Deploying PostgreSQL..."
    
    if [ -f "k8s/postgres-statefulset.yaml" ]; then
        log_command "kubectl apply -f k8s/postgres-statefulset.yaml"
        kubectl apply -f k8s/postgres-statefulset.yaml
    else
        log_warning "PostgreSQL manifest not found, creating minimal deployment..."
        create_minimal_postgresql
    fi
    
    # Wait for PostgreSQL to be ready
    log_info "Waiting for PostgreSQL to be ready..."
    kubectl wait --for=condition=ready pod -l app=postgres -n $NAMESPACE --timeout=300s
    
    log_success "PostgreSQL deployed"
}

create_minimal_postgresql() {
    cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: eduai
spec:
  serviceName: postgres-service
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
          ports:
            - containerPort: 5432
          env:
            - name: POSTGRES_DB
              value: eduai_db
            - name: POSTGRES_USER
              value: postgres
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: eduai-secrets
                  key: DB_PASSWORD
          volumeMounts:
            - name: postgres-storage
              mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
    - metadata:
        name: postgres-storage
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 10Gi
---
apiVersion: v1
kind: Service
metadata:
  name: postgres-service
  namespace: eduai
spec:
  selector:
    app: postgres
  ports:
    - port: 5432
      targetPort: 5432
  type: ClusterIP
EOF
}

deploy_redis() {
    log_step "Deploying Redis..."
    
    if [ -f "k8s/redis-deployment.yaml" ]; then
        log_command "kubectl apply -f k8s/redis-deployment.yaml"
        kubectl apply -f k8s/redis-deployment.yaml
    else
        log_warning "Redis manifest not found, creating minimal deployment..."
        create_minimal_redis
    fi
    
    # Wait for Redis to be ready
    log_info "Waiting for Redis to be ready..."
    kubectl wait --for=condition=ready pod -l app=redis -n $NAMESPACE --timeout=300s
    
    log_success "Redis deployed"
}

create_minimal_redis() {
    cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: eduai
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
          command:
            - redis-server
            - --requirepass
            - \$(REDIS_PASSWORD)
          env:
            - name: REDIS_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: eduai-secrets
                  key: REDIS_PASSWORD
          ports:
            - containerPort: 6379
---
apiVersion: v1
kind: Service
metadata:
  name: redis-service
  namespace: eduai
spec:
  selector:
    app: redis
  ports:
    - port: 6379
      targetPort: 6379
  type: ClusterIP
EOF
}

deploy_backend() {
    log_step "Deploying Backend API..."
    
    if [ -f "k8s/backend-deployment.yaml" ]; then
        log_command "kubectl apply -f k8s/backend-deployment.yaml"
        kubectl apply -f k8s/backend-deployment.yaml
    else
        log_warning "Backend manifest not found, creating minimal deployment..."
        create_minimal_backend
    fi
    
    # Wait for Backend to be ready
    log_info "Waiting for Backend to be ready..."
    kubectl wait --for=condition=available deployment/backend -n $NAMESPACE --timeout=300s
    
    log_success "Backend API deployed"
}

create_minimal_backend() {
    cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: eduai
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
          image: node:18-alpine
          command: ["sh", "-c", "echo 'Backend placeholder' && sleep 3600"]
          ports:
            - containerPort: 5000
          envFrom:
            - configMapRef:
                name: eduai-config
          env:
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: eduai-secrets
                  key: DB_PASSWORD
          resources:
            requests:
              cpu: "100m"
              memory: "256Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"
---
apiVersion: v1
kind: Service
metadata:
  name: backend-service
  namespace: eduai
spec:
  selector:
    app: backend
  ports:
    - port: 5000
      targetPort: 5000
  type: ClusterIP
EOF
}

deploy_ai_service() {
    log_step "Deploying AI Service..."
    
    if [ -f "k8s/ai-service-deployment.yaml" ]; then
        log_command "kubectl apply -f k8s/ai-service-deployment.yaml"
        kubectl apply -f k8s/ai-service-deployment.yaml
    else
        log_warning "AI Service manifest not found, creating minimal deployment..."
        create_minimal_ai_service
    fi
    
    # Wait for AI Service to be ready
    log_info "Waiting for AI Service to be ready..."
    kubectl wait --for=condition=available deployment/ai-service -n $NAMESPACE --timeout=300s
    
    log_success "AI Service deployed"
}

create_minimal_ai_service() {
    cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ai-service
  namespace: eduai
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ai-service
  template:
    metadata:
      labels:
        app: ai-service
    spec:
      containers:
        - name: ai-service
          image: python:3.11-alpine
          command: ["sh", "-c", "echo 'AI Service placeholder' && sleep 3600"]
          ports:
            - containerPort: 8000
          envFrom:
            - configMapRef:
                name: eduai-config
          env:
            - name: OPENAI_API_KEY
              valueFrom:
                secretKeyRef:
                  name: eduai-secrets
                  key: OPENAI_API_KEY
          resources:
            requests:
              cpu: "200m"
              memory: "512Mi"
            limits:
              cpu: "1000m"
              memory: "2Gi"
---
apiVersion: v1
kind: Service
metadata:
  name: ai-service
  namespace: eduai
spec:
  selector:
    app: ai-service
  ports:
    - port: 8000
      targetPort: 8000
  type: ClusterIP
EOF
}

deploy_frontend() {
    log_step "Deploying Frontend..."
    
    if [ -f "k8s/frontend-deployment.yaml" ]; then
        log_command "kubectl apply -f k8s/frontend-deployment.yaml"
        kubectl apply -f k8s/frontend-deployment.yaml
    else
        log_warning "Frontend manifest not found, creating minimal deployment..."
        create_minimal_frontend
    fi
    
    # Wait for Frontend to be ready
    log_info "Waiting for Frontend to be ready..."
    kubectl wait --for=condition=available deployment/frontend -n $NAMESPACE --timeout=300s
    
    log_success "Frontend deployed"
}

create_minimal_frontend() {
    cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: eduai
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
              cpu: "50m"
              memory: "64Mi"
            limits:
              cpu: "200m"
              memory: "256Mi"
---
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
  namespace: eduai
spec:
  selector:
    app: frontend
  ports:
    - port: 80
      targetPort: 80
  type: ClusterIP
EOF
}

install_nginx_ingress() {
    log_step "Installing NGINX Ingress Controller..."
    
    # Check if ingress is already installed
    if kubectl get pods -n ingress-nginx --no-headers | grep -q "Running"; then
        log_warning "NGINX Ingress is already installed"
    else
        log_command "kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml"
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
        
        # Wait for ingress controller
        log_info "Waiting for Ingress Controller to be ready..."
        kubectl wait --namespace ingress-nginx \
            --for=condition=ready pod \
            --selector=app.kubernetes.io/component=controller \
            --timeout=300s
        
        log_success "NGINX Ingress Controller installed"
    fi
}

install_cert_manager() {
    log_step "Installing cert-manager for TLS..."
    
    # Check if cert-manager is already installed
    if kubectl get pods -n cert-manager --no-headers | grep -q "Running"; then
        log_warning "cert-manager is already installed"
    else
        log_command "kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml"
        kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
        
        # Wait for cert-manager
        log_info "Waiting for cert-manager to be ready..."
        kubectl wait --for=condition=available deployment/cert-manager -n cert-manager --timeout=300s
        kubectl wait --for=condition=available deployment/cert-manager-cainjector -n cert-manager --timeout=300s
        kubectl wait --for=condition=available deployment/cert-manager-webhook -n cert-manager --timeout=300s
        
        log_success "cert-manager installed"
    fi
    
    # Apply cluster issuers
    if [ -f "k8s/cert-manager.yaml" ]; then
        log_command "kubectl apply -f k8s/cert-manager.yaml"
        kubectl apply -f k8s/cert-manager.yaml
    else
        log_warning "cert-manager.yaml not found, creating minimal issuers..."
        create_minimal_cert_issuers
    fi
}

create_minimal_cert_issuers() {
    cat << EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@ailearn.duckdns.org
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
}

apply_ingress() {
    log_step "Applying Ingress configuration for $DOMAIN..."
    
    # Apply updated ingress
    if [ -f "k8s/ingress-updated.yaml" ]; then
        log_command "kubectl apply -f k8s/ingress-updated.yaml"
        kubectl apply -f k8s/ingress-updated.yaml
    else
        log_warning "ingress-updated.yaml not found, creating minimal ingress..."
        create_minimal_ingress
    fi
    
    log_success "Ingress configuration applied"
}

create_minimal_ingress() {
    cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ailearn-ingress
  namespace: eduai
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
    - hosts:
        - ailearn.duckdns.org
      secretName: ailearn-tls
  rules:
    - host: ailearn.duckdns.org
      http:
        paths:
          - path: /api/
            pathType: Prefix
            backend:
              service:
                name: backend-service
                port:
                  number: 5000
          - path: /ai/
            pathType: Prefix
            backend:
              service:
                name: ai-service
                port:
                  number: 8000
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend-service
                port:
                  number: 80
EOF
}

install_prometheus_monitoring() {
    log_step "Installing Prometheus monitoring..."
    
    # Add Helm repository
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    
    # Install Prometheus
    if kubectl get pods -n $MONITORING_NAMESPACE -l app.kubernetes.io/name=prometheus --no-headers | grep -q "Running"; then
        log_warning "Prometheus is already installed"
    else
        log_command "helm install prometheus prometheus-community/kube-prometheus-stack --namespace $MONITORING_NAMESPACE --create-namespace"
        helm install prometheus prometheus-community/kube-prometheus-stack \
            --namespace $MONITORING_NAMESPACE \
            --create-namespace \
            --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=20Gi \
            --set grafana.adminPassword=admin123 \
            --set grafana.ingress.enabled=true \
            --set grafana.ingress.hosts[0]=grafana.$DOMAIN
        
        log_success "Prometheus monitoring installed"
    fi
}

install_grafana_dashboards() {
    log_step "Installing Grafana dashboards..."
    
    # Wait for Grafana to be ready
    kubectl wait --for=condition=available deployment/grafana -n $MONITORING_NAMESPACE --timeout=300s
    
    # Import dashboards
    log_info "Creating Grafana dashboard ConfigMaps..."
    
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboards
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  ailearn-overview.json: |
    {
      "dashboard": {
        "id": null,
        "title": "AI Learn Platform Overview",
        "tags": ["ailearn"],
        "timezone": "browser",
        "panels": [
          {
            "title": "Application Status",
            "type": "stat",
            "targets": [
              {
                "expr": "up{job=\"kubernetes-pods\"}",
                "legendFormat": "{{pod}}"
              }
            ]
          }
        ],
        "time": {
          "from": "now-1h",
          "to": "now"
        },
        "refresh": "5s"
      }
    }
EOF
    
    log_success "Grafana dashboards installed"
}

deploy_argocd() {
    log_step "Deploying ArgoCD for GitOps..."
    
    # Check if ArgoCD is already installed
    if kubectl get pods -n argocd --no-headers | grep -q "Running"; then
        log_warning "ArgoCD is already installed"
    else
        # Install ArgoCD
        log_command "kubectl create namespace argocd"
        kubectl create namespace argocd
        
        log_command "kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
        kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
        
        # Wait for ArgoCD
        log_info "Waiting for ArgoCD to be ready..."
        kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s
        
        log_success "ArgoCD deployed"
    fi
    
    # Create ArgoCD application
    if [ -f "k8s/argocd-application.yaml" ]; then
        log_command "kubectl apply -f k8s/argocd-application.yaml"
        kubectl apply -f k8s/argocd-application.yaml
    else
        log_warning "ArgoCD application manifest not found"
    fi
}

show_service_urls() {
    log_step "Service URLs and Access Information"
    
    echo -e "\n${GREEN}🎉 AI Smart Learning Platform deployed successfully!${NC}\n"
    
    echo -e "${CYAN}📱 Application URLs:${NC}"
    echo -e "   🌐 Frontend:     ${YELLOW}https://$DOMAIN${NC}"
    echo -e "   🔧 Backend API:  ${YELLOW}https://$DOMAIN/api${NC}"
    echo -e "   🤖 AI Service:   ${YELLOW}https://$DOMAIN/ai${NC}"
    
    echo -e "\n${CYAN}📊 Monitoring URLs:${NC}"
    echo -e "   📈 Grafana:      ${YELLOW}https://grafana.$DOMAIN${NC} (admin/admin123)"
    echo -e "   🔍 Prometheus:   ${YELLOW}http://$(kubectl get svc prometheus -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}' || echo 'localhost'):9090${NC}"
    
    echo -e "\n${CYAN}🔧 Local Access (if external doesn't work):${NC}"
    echo -e "   🌐 Frontend:     ${YELLOW}http://localhost:8080${NC}"
    echo -e "   🔧 Backend API:  ${YELLOW}http://localhost:5000${NC}"
    echo -e "   🤖 AI Service:   ${YELLOW}http://localhost:8000${NC}"
    echo -e "   📈 Grafana:      ${YELLOW}http://localhost:3000${NC}"
    echo -e "   🔍 Prometheus:   ${YELLOW}http://localhost:9090${NC}"
    
    echo -e "\n${CYAN}📱 Port Forwarding Commands:${NC}"
    echo -e "   kubectl port-forward -n $NAMESPACE svc/frontend-service 8080:80"
    echo -e "   kubectl port-forward -n $NAMESPACE svc/backend-service 5000:5000"
    echo -e "   kubectl port-forward -n $NAMESPACE svc/ai-service 8000:8000"
    echo -e "   kubectl port-forward -n $MONITORING_NAMESPACE svc/grafana 3000:3000"
    echo -e "   kubectl port-forward -n $MONITORING_NAMESPACE svc/prometheus 9090:9090"
    
    echo -e "\n${CYAN}🔍 Status Commands:${NC}"
    echo -e "   kubectl get pods -n $NAMESPACE"
    echo -e "   kubectl get services -n $NAMESPACE"
    echo -e "   kubectl get ingress -n $NAMESPACE"
    echo -e "   kubectl logs -f deployment/backend -n $NAMESPACE"
    
    echo -e "\n${GREEN}✨ Happy Learning! ✨${NC}\n"
}

verify_deployment() {
    log_step "Verifying deployment..."
    
    echo -e "\n${CYAN}📊 Pod Status:${NC}"
    kubectl get pods -n $NAMESPACE
    
    echo -e "\n${CYAN}🔗 Service Status:${NC}"
    kubectl get services -n $NAMESPACE
    
    echo -e "\n${CYAN}🌐 Ingress Status:${NC}"
    kubectl get ingress -n $NAMESPACE
    
    echo -e "\n${CYAN}📈 Monitoring Status:${NC}"
    kubectl get pods -n $MONITORING_NAMESPACE
    
    # Check if all deployments are ready
    log_info "Checking deployment readiness..."
    
    if kubectl wait --for=condition=available deployment/frontend -n $NAMESPACE --timeout=60s 2>/dev/null; then
        log_success "Frontend is ready"
    else
        log_warning "Frontend may not be fully ready"
    fi
    
    if kubectl wait --for=condition=available deployment/backend -n $NAMESPACE --timeout=60s 2>/dev/null; then
        log_success "Backend is ready"
    else
        log_warning "Backend may not be fully ready"
    fi
    
    if kubectl wait --for=condition=available deployment/ai-service -n $NAMESPACE --timeout=60s 2>/dev/null; then
        log_success "AI Service is ready"
    else
        log_warning "AI Service may not be fully ready"
    fi
}

cleanup() {
    log_warning "Cleaning up deployment..."
    
    # Delete all resources
    kubectl delete namespace $NAMESPACE --ignore-not-found=true
    kubectl delete namespace $MONITORING_NAMESPACE --ignore-not-found=true
    kubectl delete namespace argocd --ignore-not-found=true
    kubectl delete namespace cert-manager --ignore-not-found=true
    
    # Stop minikube
    minikube stop --name $CLUSTER_NAME
    
    log_success "Cleanup completed"
}

show_help() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  deploy     - Deploy the complete platform (default)"
    echo "  verify     - Verify deployment status"
    echo "  cleanup    - Delete all deployed resources"
    echo "  help       - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0              # Deploy everything"
    echo "  $0 deploy       # Deploy everything"
    echo "  $0 verify       # Check deployment status"
    echo "  $0 cleanup      # Delete everything"
    echo ""
    echo "Platform will be available at: https://ailearn.duckdns.org"
}

# Main script logic
main() {
    show_banner
    
    case "${1:-deploy}" in
        "deploy")
            check_prerequisites
            start_minikube_cluster
            create_namespaces
            apply_secrets_and_configmaps
            deploy_postgresql
            deploy_redis
            deploy_backend
            deploy_ai_service
            deploy_frontend
            install_nginx_ingress
            install_cert_manager
            apply_ingress
            install_prometheus_monitoring
            install_grafana_dashboards
            deploy_argocd
            verify_deployment
            show_service_urls
            log_success "🎉 AI Smart Learning Platform deployment completed!"
            ;;
        "verify")
            verify_deployment
            show_service_urls
            ;;
        "cleanup")
            cleanup
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"
