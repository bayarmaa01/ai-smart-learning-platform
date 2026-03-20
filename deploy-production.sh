#!/usr/bin/env bash

# ==========================================================
#  EDUAI - Production Grade Kubernetes Deployment Script
# ==========================================================
# Features
# - Auto Minikube cluster setup
# - Docker build & push with BuildKit
# - Kubernetes deployment with HPA
# - Production monitoring stack
# - TLS with cert-manager
# - Centralized logging
# - Network security policies
# - Complete observability
# ==========================================================

set -euo pipefail

############################################
# CONFIGURATION
############################################

CLUSTER_NAME="eduai-cluster"
NAMESPACE="eduai"
MONITORING_NAMESPACE="monitoring"
DOMAIN="ailearn.duckdns.org"
DOCKER_USERNAME="bayarmaa"

FRONTEND_IMAGE="$DOCKER_USERNAME/eduai-frontend:latest"
BACKEND_IMAGE="$DOCKER_USERNAME/eduai-backend:latest"
AI_IMAGE="$DOCKER_USERNAME/eduai-ai-service:latest"

MINIKUBE_CPUS=4
MINIKUBE_MEMORY=6144

############################################
# COLORS
############################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

############################################
# LOGGING
############################################

log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

fail() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

cmd() {
    echo -e "${CYAN}[CMD]${NC} $1"
}

show_banner() {
    echo -e "${CYAN}"
    cat << "EOF"
    ____        __          __   _                 
   / __ \____  / /_  ____ _ / /  (_)___  ____ _ 
  / /_/ / __ \/ __ \/ __ \`// /  / / __ \/ __ \`/
 / ____/ /_/ / / / /_/ // /__/ / / / / /_/ /  
/_/    \____/_/ /_/\__,_//____/_/ /_/ /_/\__,_/   
                                                   
    EDUAI - Production DevOps Platform
    AI Smart Learning Platform SaaS
    Domain: $DOMAIN
    Docker: $DOCKER_USERNAME
EOF
    echo -e "${NC}"
}

############################################
# CHECK DEPENDENCIES
############################################

check_dependencies() {
    log "Checking dependencies..."
    
    local missing=()
    
    for cmd in kubectl docker helm minikube; do
        if ! command -v $cmd &> /dev/null; then
            missing+=($cmd)
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        fail "Missing dependencies: ${missing[*]}"
    fi
    
    # Check Docker BuildKit
    if ! docker buildx version &> /dev/null; then
        warn "Docker BuildKit not available, enabling..."
        docker buildx install
    fi
    
    success "All dependencies available"
}

############################################
# START MINIKUBE CLUSTER
############################################

start_cluster() {
    step "Starting Minikube cluster..."
    
    if minikube status -p $CLUSTER_NAME &>/dev/null; then
        log "Cluster already exists, checking status..."
        if ! minikube status -p $CLUSTER_NAME | grep -q "Running"; then
            log "Starting existing cluster..."
            minikube start -p $CLUSTER_NAME
        fi
    else
        log "Creating new cluster..."
        minikube start \
            -p $CLUSTER_NAME \
            --cpus=$MINIKUBE_CPUS \
            --memory=$MINIKUBE_MEMORY \
            --disk-size=50g \
            --kubernetes-version=v1.28.0 \
            --driver=docker \
            --container-runtime=docker
    fi
    
    # Set kubectl context
    kubectl config use-context $CLUSTER_NAME
    
    # Enable required addons
    log "Enabling Minikube addons..."
    minikube addons enable ingress -p $CLUSTER_NAME
    minikube addons enable metrics-server -p $CLUSTER_NAME
    minikube addons enable dashboard -p $CLUSTER_NAME
    
    # Connect Docker to Minikube
    eval $(minikube -p $CLUSTER_NAME docker-env)
    
    success "Minikube cluster ready"
}

############################################
# BUILD DOCKER IMAGES
############################################

build_images() {
    step "Building Docker images with BuildKit..."
    
    # Use BuildKit for better caching and parallel builds
    export DOCKER_BUILDKIT=1
    
    # Build frontend
    log "Building frontend image..."
    docker buildx build \
        --platform linux/amd64,linux/arm64 \
        --tag $FRONTEND_IMAGE \
        --cache-from type=local,src=frontend \
        --cache-to type=local,dest=frontend \
        ./frontend
    
    # Build backend
    log "Building backend image..."
    docker buildx build \
        --platform linux/amd64,linux/arm64 \
        --tag $BACKEND_IMAGE \
        --cache-from type=local,src=backend \
        --cache-to type=local,dest=backend \
        ./backend
    
    # Build AI service
    log "Building AI service image..."
    docker buildx build \
        --platform linux/amd64,linux/arm64 \
        --tag $AI_IMAGE \
        --cache-from type=local,src=ai-service \
        --cache-to type=local,dest=ai-service \
        ./ai-service
    
    success "All images built successfully"
}

############################################
# PUSH IMAGES
############################################

push_images() {
    step "Pushing images to Docker Hub..."
    
    # Check if running locally
    if minikube status -p $CLUSTER_NAME &>/dev/null && minikube status -p $CLUSTER_NAME | grep -q "Running"; then
        log "Running in Minikube, skipping Docker Hub push"
        log "Images are available in Minikube Docker daemon"
        return 0
    fi
    
    # Login to Docker Hub
    log "Please login to Docker Hub:"
    docker login
    
    # Push images
    docker push $FRONTEND_IMAGE
    docker push $BACKEND_IMAGE
    docker push $AI_IMAGE
    
    success "All images pushed to Docker Hub"
}

############################################
# CREATE NAMESPACES
############################################

create_namespaces() {
    step "Creating Kubernetes namespaces..."
    
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace $MONITORING_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace logging --dry-run=client -o yaml | kubectl apply -f -
    
    success "Namespaces created"
}

############################################
# DEPLOY INFRASTRUCTURE
############################################

deploy_infrastructure() {
    step "Deploying infrastructure services..."
    
    # Deploy PostgreSQL
    log "Deploying PostgreSQL..."
    kubectl apply -n $NAMESPACE -f - <<EOF
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: postgres
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
        fsGroup: 999
      containers:
      - name: postgres
        image: postgres:15-alpine
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
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        resources:
          requests:
            cpu: "250m"
            memory: "512Mi"
          limits:
            cpu: "1000m"
            memory: "2Gi"
        livenessProbe:
          exec:
            command: ["pg_isready", "-U", "postgres", "-d", "eduai_db"]
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command: ["pg_isready", "-U", "postgres", "-d", "eduai_db"]
          initialDelaySeconds: 5
          periodSeconds: 5
  volumeClaimTemplates:
  - metadata:
      name: postgres-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 20Gi
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: $NAMESPACE
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432
  type: ClusterIP
EOF
    
    # Deploy Redis
    log "Deploying Redis..."
    kubectl apply -n $NAMESPACE -f - <<EOF
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis
spec:
  serviceName: redis
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      securityContext:
        runAsUser: 999
        fsGroup: 999
      containers:
      - name: redis
        image: redis:7-alpine
        command:
          - redis-server
          - --requirepass
          - \$(REDIS_PASSWORD)
          - --maxmemory
          - 512mb
          - --maxmemory-policy
          - allkeys-lru
          - --save
          - "900 1"
          - --appendonly
          - "yes"
        env:
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: eduai-secrets
              key: REDIS_PASSWORD
        ports:
        - containerPort: 6379
        volumeMounts:
        - name: redis-storage
          mountPath: /data
        resources:
          requests:
            cpu: "100m"
            memory: "256Mi"
          limits:
            cpu: "500m"
            memory: "1Gi"
        livenessProbe:
          exec:
            command: ["redis-cli", "ping"]
          initialDelaySeconds: 15
          periodSeconds: 10
        readinessProbe:
          exec:
            command: ["redis-cli", "ping"]
          initialDelaySeconds: 5
          periodSeconds: 5
  volumeClaimTemplates:
  - metadata:
      name: redis-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 5Gi
---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: $NAMESPACE
spec:
  selector:
    app: redis
  ports:
  - port: 6379
    targetPort: 6379
  type: ClusterIP
EOF
    
    success "Infrastructure deployed"
}

############################################
# DEPLOY APPLICATIONS
############################################

deploy_applications() {
    step "Deploying application services..."
    
    # Deploy Backend
    log "Deploying Backend API..."
    kubectl apply -n $NAMESPACE -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  labels:
    app: backend
    version: "1.0.0"
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: backend
        version: "1.0.0"
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "5000"
        prometheus.io/path: "/metrics"
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
        fsGroup: 1001
      terminationGracePeriodSeconds: 30
      containers:
      - name: backend
        image: $BACKEND_IMAGE
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 5000
          name: http
        envFrom:
        - configMapRef:
            name: eduai-config
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: eduai-secrets
              key: DB_PASSWORD
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: eduai-secrets
              key: JWT_SECRET
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: eduai-secrets
              key: REDIS_PASSWORD
        resources:
          requests:
            cpu: "100m"
            memory: "256Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
        livenessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: false
          capabilities:
            drop:
            - ALL
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: $NAMESPACE
  labels:
    app: backend
spec:
  selector:
    app: backend
  ports:
  - port: 5000
    targetPort: 5000
    name: http
  type: ClusterIP
EOF
    
    # Deploy AI Service
    log "Deploying AI Service..."
    kubectl apply -n $NAMESPACE -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ai-service
  labels:
    app: ai-service
    version: "1.0.0"
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ai-service
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: ai-service
        version: "1.0.0"
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8000"
        prometheus.io/path: "/metrics"
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
      terminationGracePeriodSeconds: 60
      containers:
      - name: ai-service
        image: $AI_IMAGE
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8000
          name: http
        envFrom:
        - configMapRef:
            name: eduai-config
        env:
        - name: OPENAI_API_KEY
          valueFrom:
            secretKeyRef:
              name: eduai-secrets
              key: OPENAI_API_KEY
        - name: REDIS_URL
          value: "redis://:$(REDIS_PASSWORD)@redis:6379"
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: eduai-secrets
              key: REDIS_PASSWORD
        resources:
          requests:
            cpu: "200m"
            memory: "512Mi"
          limits:
            cpu: "1000m"
            memory: "2Gi"
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 60
          periodSeconds: 15
          timeoutSeconds: 10
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
---
apiVersion: v1
kind: Service
metadata:
  name: ai-service
  namespace: $NAMESPACE
  labels:
    app: ai-service
spec:
  selector:
    app: ai-service
  ports:
  - port: 8000
    targetPort: 8000
    name: http
  type: ClusterIP
EOF
    
    # Deploy Frontend
    log "Deploying Frontend..."
    kubectl apply -n $NAMESPACE -f - <<EOF
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
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: frontend
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
      containers:
      - name: frontend
        image: $FRONTEND_IMAGE
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: "50m"
            memory: "64Mi"
          limits:
            cpu: "200m"
            memory: "256Mi"
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: false
          capabilities:
            drop:
            - ALL
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: $NAMESPACE
  labels:
    app: frontend
spec:
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF
    
    success "Applications deployed"
}

############################################
# CONFIGURE AUTOSCALING
############################################

configure_autoscaling() {
    step "Configuring Horizontal Pod Autoscaling..."
    
    # Backend HPA
    kubectl apply -n $NAMESPACE -f - <<EOF
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: backend-hpa
  namespace: $NAMESPACE
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: backend
  minReplicas: 3
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
EOF
    
    # AI Service HPA
    kubectl apply -n $NAMESPACE -f - <<EOF
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: ai-service-hpa
  namespace: $NAMESPACE
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: ai-service
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60
EOF
    
    success "Autoscaling configured"
}

############################################
# INSTALL INGRESS AND TLS
############################################

install_ingress_tls() {
    step "Installing NGINX Ingress and TLS..."
    
    # Install NGINX Ingress Controller
    log "Installing NGINX Ingress Controller..."
    if ! kubectl get namespace ingress-nginx &>/dev/null; then
        kubectl create namespace ingress-nginx
    fi
    
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
    
    # Wait for ingress controller
    log "Waiting for Ingress Controller to be ready..."
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=300s
    
    # Install cert-manager
    log "Installing cert-manager..."
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
    
    # Wait for cert-manager
    log "Waiting for cert-manager to be ready..."
    kubectl wait --for=condition=available deployment/cert-manager -n cert-manager --timeout=300s
    kubectl wait --for=condition=available deployment/cert-manager-cainjector -n cert-manager --timeout=300s
    kubectl wait --for=condition=available deployment/cert-manager-webhook -n cert-manager --timeout=300s
    
    # Create Cluster Issuer
    log "Creating Let's Encrypt Cluster Issuer..."
    kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@$DOMAIN
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
    
    # Create Secrets
    log "Creating application secrets..."
    kubectl apply -n $NAMESPACE -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: eduai-secrets
  namespace: $NAMESPACE
type: Opaque
data:
  DB_PASSWORD: ZWR1YWlfZGIxMjM=
  REDIS_PASSWORD: cmVkaXMxMjM=
  JWT_SECRET: bXlzZWNyZXRrZXkxMjM=
  JWT_REFRESH_SECRET: bXlzZWNyZXRrZXlyZWZyZXNoMTIz
  OPENAI_API_KEY: c2stcHJvamVjdDEyMw==
  AI_SERVICE_API_KEY: YWktc2VydmljZS1rZXkxMjM=
EOF
    
    # Create ConfigMap
    kubectl apply -n $NAMESPACE -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: eduai-config
  namespace: $NAMESPACE
data:
  NODE_ENV: "production"
  PORT: "5000"
  DB_HOST: "postgres"
  DB_PORT: "5432"
  DB_NAME: "eduai_db"
  DB_USER: "postgres"
  REDIS_URL: "redis://redis:6379"
  AI_SERVICE_URL: "http://ai-service:8000"
  LOG_LEVEL: "info"
  ALLOWED_ORIGINS: "https://$DOMAIN"
EOF
    
    # Create Ingress
    log "Creating Ingress with TLS..."
    kubectl apply -n $NAMESPACE -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: eduai-ingress
  namespace: $NAMESPACE
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "60"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "60"
    nginx.ingress.kubernetes.io/rate-limit: "100"
    nginx.ingress.kubernetes.io/rate-limit-window: "1m"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/cors-allow-origin: "https://$DOMAIN"
    nginx.ingress.kubernetes.io/cors-allow-methods: "GET, POST, PUT, DELETE, OPTIONS"
    nginx.ingress.kubernetes.io/cors-allow-headers: "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization"
    nginx.ingress.kubernetes.io/configuration-snippet: |
      more_set_headers "X-Frame-Options: SAMEORIGIN";
      more_set_headers "X-Content-Type-Options: nosniff";
      more_set_headers "X-XSS-Protection: 1; mode=block";
      more_set_headers "Referrer-Policy: strict-origin-when-cross-origin";
spec:
  tls:
    - hosts:
        - $DOMAIN
      secretName: eduai-tls
  rules:
    - host: $DOMAIN
      http:
        paths:
          - path: /api/
            pathType: Prefix
            backend:
              service:
                name: backend
                port:
                  number: 5000
          - path: /ai/
            pathType: Prefix
            backend:
              service:
                name: ai-service
                port:
                  number: 8000
          - path: /socket.io/
            pathType: Prefix
            backend:
              service:
                name: backend
                port:
                  number: 5000
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend
                port:
                  number: 80
EOF
    
    success "Ingress and TLS configured"
}

############################################
# INSTALL MONITORING STACK
############################################

install_monitoring() {
    step "Installing production monitoring stack..."
    
    # Add Helm repositories
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo update
    
    # Install Prometheus Stack
    log "Installing Prometheus monitoring stack..."
    helm install prometheus prometheus-community/kube-prometheus-stack \
        --namespace $MONITORING_NAMESPACE \
        --create-namespace \
        --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=50Gi \
        --set prometheus.prometheusSpec.retention=15d \
        --set grafana.adminPassword=admin123 \
        --set grafana.ingress.enabled=true \
        --set grafana.ingress.hosts[0]=grafana.$DOMAIN \
        --set grafana.ingress.tls[0].hosts[0]=grafana.$DOMAIN \
        --set grafana.ingress.tls[0].secretName=grafana-tls \
        --set grafana.sidecar.datasources.enabled=true \
        --set grafana.sidecar.dashboards.enabled=true
    
    # Wait for monitoring stack
    log "Waiting for monitoring stack to be ready..."
    kubectl wait --for=condition=available deployment/prometheus-grafana -n $MONITORING_NAMESPACE --timeout=300s
    kubectl wait --for=condition=available deployment/prometheus-kube-prometheus-stack-prometheus -n $MONITORING_NAMESPACE --timeout=300s
    
    success "Monitoring stack installed"
}

############################################
# INSTALL LOGGING STACK
############################################

install_logging() {
    step "Installing centralized logging..."
    
    # Add Loki Helm repository
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo update
    
    # Install Loki
    log "Installing Loki log aggregation..."
    helm install loki grafana/loki-stack \
        --namespace logging \
        --create-namespace \
        --set loki.persistence.enabled=true \
        --set loki.persistence.size=20Gi \
        --set promtail.enabled=true \
        --set promtail.config.clients[0].url=http://loki.logging:3100/loki/api/v1/push
    
    success "Logging stack installed"
}

############################################
# CONFIGURE NETWORK SECURITY
############################################

configure_security() {
    step "Configuring network security policies..."
    
    # Default deny policy
    kubectl apply -n $NAMESPACE -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: $NAMESPACE
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF
    
    # Allow specific traffic
    kubectl apply -n $NAMESPACE -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: eduai-network-policy
  namespace: $NAMESPACE
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    - podSelector:
        matchLabels:
          app: frontend
    - podSelector:
        matchLabels:
          app: backend
    - podSelector:
        matchLabels:
          app: ai-service
  - ports:
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 5000
    - protocol: TCP
      port: 8000
    - protocol: TCP
      port: 5432
    - protocol: TCP
      port: 6379
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: postgres
    - podSelector:
        matchLabels:
          app: redis
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
  - to: []
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 80
EOF
    
    success "Network security policies configured"
}

############################################
# WAIT FOR DEPLOYMENT
############################################

wait_for_deployment() {
    step "Waiting for all deployments to be ready..."
    
    # Wait for infrastructure
    log "Waiting for PostgreSQL..."
    kubectl wait --for=condition=ready pod -l app=postgres -n $NAMESPACE --timeout=300s
    
    log "Waiting for Redis..."
    kubectl wait --for=condition=ready pod -l app=redis -n $NAMESPACE --timeout=300s
    
    # Wait for applications
    log "Waiting for Backend..."
    kubectl wait --for=condition=available deployment/backend -n $NAMESPACE --timeout=300s
    
    log "Waiting for AI Service..."
    kubectl wait --for=condition=available deployment/ai-service -n $NAMESPACE --timeout=300s
    
    log "Waiting for Frontend..."
    kubectl wait --for=condition=available deployment/frontend -n $NAMESPACE --timeout=300s
    
    success "All deployments ready"
}

############################################
# SHOW ACCESS INFORMATION
############################################

show_access_info() {
    step "Deployment completed successfully!"
    
    echo -e "\n${GREEN}🎉 EDUAI Platform Deployed Successfully!${NC}\n"
    
    echo -e "${CYAN}📱 Application URLs:${NC}"
    echo -e "   🌐 Frontend:     ${YELLOW}https://$DOMAIN${NC}"
    echo -e "   🔧 Backend API:  ${YELLOW}https://$DOMAIN/api${NC}"
    echo -e "   🤖 AI Service:   ${YELLOW}https://$DOMAIN/ai${NC}"
    
    echo -e "\n${CYAN}📊 Monitoring URLs:${NC}"
    echo -e "   📈 Grafana:      ${YELLOW}https://grafana.$DOMAIN${NC} (admin/admin123)"
    echo -e "   🔍 Prometheus:   ${YELLOW}https://prometheus.$DOMAIN${NC}"
    echo -e "   📋 Logs:        ${YELLOW}https://loki.$DOMAIN${NC}"
    
    echo -e "\n${CYAN}🔧 Local Access (if needed):${NC}"
    echo -e "   🌐 Frontend:     ${YELLOW}http://localhost:80${NC}"
    echo -e "   🔧 Backend API:  ${YELLOW}http://localhost:5000${NC}"
    echo -e "   🤖 AI Service:   ${YELLOW}http://localhost:8000${NC}"
    
    echo -e "\n${CYAN}📱 Port Forwarding Commands:${NC}"
    echo -e "   kubectl port-forward -n $NAMESPACE svc/frontend 8080:80"
    echo -e "   kubectl port-forward -n $NAMESPACE svc/backend 5000:5000"
    echo -e "   kubectl port-forward -n $NAMESPACE svc/ai-service 8000:8000"
    echo -e "   kubectl port-forward -n $MONITORING_NAMESPACE svc/prometheus-grafana 3000:3000"
    
    echo -e "\n${CYAN}🔍 Status Commands:${NC}"
    echo -e "   kubectl get pods -n $NAMESPACE"
    echo -e "   kubectl get services -n $NAMESPACE"
    echo -e "   kubectl get ingress -n $NAMESPACE"
    echo -e "   kubectl get hpa -n $NAMESPACE"
    echo -e "   kubectl top pods -n $NAMESPACE"
    
    echo -e "\n${CYAN}🐳 Docker Images:${NC}"
    echo -e "   $FRONTEND_IMAGE"
    echo -e "   $BACKEND_IMAGE"
    echo -e "   $AI_IMAGE"
    
    echo -e "\n${GREEN}✨ EDUAI Platform is ready for production use! ✨${NC}\n"
}

############################################
# CLEANUP FUNCTION
############################################

cleanup() {
    step "Cleaning up deployment..."
    
    # Delete all resources
    kubectl delete namespace $NAMESPACE --ignore-not-found=true --wait=true
    kubectl delete namespace $MONITORING_NAMESPACE --ignore-not-found=true --wait=true
    kubectl delete namespace logging --ignore-not-found=true --wait=true
    kubectl delete namespace ingress-nginx --ignore-not-found=true --wait=true
    kubectl delete namespace cert-manager --ignore-not-found=true --wait=true
    
    # Stop minikube
    minikube stop -p $CLUSTER_NAME
    
    success "Cleanup completed"
}

############################################
# SHOW HELP
############################################

show_help() {
    echo "EDUAI - Production Grade Kubernetes Deployment"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  deploy     - Deploy complete platform (default)"
    echo "  build      - Build Docker images only"
    echo "  push       - Push images to Docker Hub only"
    echo "  monitor    - Install monitoring stack only"
    echo "  verify     - Verify deployment status"
    echo "  cleanup    - Delete all deployed resources"
    echo "  help       - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0              # Deploy everything"
    echo "  $0 deploy       # Deploy everything"
    echo "  $0 build        # Build images only"
    echo "  $0 verify       # Check deployment status"
    echo "  $0 cleanup      # Delete everything"
    echo ""
    echo "Platform will be available at: https://$DOMAIN"
    echo "Docker Hub: $DOCKER_USERNAME"
}

############################################
# MAIN FUNCTION
############################################

main() {
    show_banner
    
    case "${1:-deploy}" in
        "deploy")
            check_dependencies
            start_cluster
            create_namespaces
            build_images
            push_images
            deploy_infrastructure
            deploy_applications
            configure_autoscaling
            install_ingress_tls
            install_monitoring
            install_logging
            configure_security
            wait_for_deployment
            show_access_info
            ;;
        "build")
            check_dependencies
            build_images
            ;;
        "push")
            check_dependencies
            push_images
            ;;
        "monitor")
            check_dependencies
            install_monitoring
            ;;
        "verify")
            check_dependencies
            echo -e "\n${CYAN}📊 Pod Status:${NC}"
            kubectl get pods -n $NAMESPACE
            echo -e "\n${CYAN}🔗 Service Status:${NC}"
            kubectl get services -n $NAMESPACE
            echo -e "\n${CYAN}🌐 Ingress Status:${NC}"
            kubectl get ingress -n $NAMESPACE
            echo -e "\n${CYAN}📈 HPA Status:${NC}"
            kubectl get hpa -n $NAMESPACE
            ;;
        "cleanup")
            cleanup
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            fail "Unknown command: $1"
            ;;
    esac
}

# Execute main function
main "$@"
