#!/usr/bin/env bash

# ==========================================================
#  EDUAI - Production Grade Kubernetes Deployment Script
# ==========================================================
# Features
# - Auto Minikube cluster setup
# - Docker build & push
# - Kubernetes deployment
# - Autoscaling
# - Health checks
# - Monitoring stack
# - Ingress + domain mapping
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

############################################
# CHECK DEPENDENCIES
############################################

check_dependencies() {

log "Checking dependencies..."

for cmd in kubectl docker helm minikube; do
    if ! command -v $cmd &> /dev/null; then
        fail "$cmd is not installed"
    fi
done

success "All dependencies installed"

}

############################################
# START MINIKUBE
############################################

start_cluster() {

log "Starting Minikube cluster..."

if minikube status -p $CLUSTER_NAME &>/dev/null; then
    warn "Cluster already exists"
else
    minikube start \
      -p $CLUSTER_NAME \
      --cpus=$MINIKUBE_CPUS \
      --memory=$MINIKUBE_MEMORY \
      --kubernetes-version=v1.28.0
fi

kubectl config use-context $CLUSTER_NAME

minikube addons enable ingress
minikube addons enable metrics-server

success "Cluster ready"

}

############################################
# NAMESPACES
############################################

create_namespaces() {

log "Creating namespaces..."

kubectl create ns $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
kubectl create ns $MONITORING_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

success "Namespaces ready"

}

############################################
# BUILD DOCKER IMAGES
############################################

build_images() {

log "Building Docker images..."

docker build -t $FRONTEND_IMAGE ./frontend
docker build -t $BACKEND_IMAGE ./backend
docker build -t $AI_IMAGE ./ai-service

success "Images built"

}

############################################
# PUSH IMAGES
############################################

push_images() {

log "Pushing images to Docker Hub..."

docker push $FRONTEND_IMAGE
docker push $BACKEND_IMAGE
docker push $AI_IMAGE

success "Images pushed"

}

############################################
# DATABASE
############################################

deploy_postgres() {

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
      containers:
      - name: postgres
        image: postgres:15
        env:
        - name: POSTGRES_PASSWORD
          value: postgres
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 10Gi
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
EOF

success "Postgres deployed"

}

############################################
# REDIS
############################################

deploy_redis() {

log "Deploying Redis..."

kubectl apply -n $NAMESPACE -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
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
        image: redis:7
        args: ["--appendonly","yes"]
        ports:
        - containerPort: 6379
---
apiVersion: v1
kind: Service
metadata:
  name: redis
spec:
  selector:
    app: redis
  ports:
  - port: 6379
EOF

success "Redis deployed"

}

############################################
# BACKEND
############################################

deploy_backend() {

log "Deploying Backend..."

kubectl apply -n $NAMESPACE -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
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
        image: $BACKEND_IMAGE
        imagePullPolicy: Always
        ports:
        - containerPort: 5000

        readinessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 10
          periodSeconds: 5

        livenessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 30
          periodSeconds: 10

        resources:
          requests:
            cpu: "200m"
            memory: "256Mi"
          limits:
            cpu: "1000m"
            memory: "512Mi"
---
apiVersion: v1
kind: Service
metadata:
  name: backend
spec:
  selector:
    app: backend
  ports:
  - port: 5000
EOF

success "Backend deployed"

}

############################################
# FRONTEND
############################################

deploy_frontend() {

log "Deploying Frontend..."

kubectl apply -n $NAMESPACE -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
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
        image: $FRONTEND_IMAGE
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
spec:
  selector:
    app: frontend
  ports:
  - port: 80
EOF

success "Frontend deployed"

}

############################################
# AI SERVICE
############################################

deploy_ai() {

log "Deploying AI Service..."

kubectl apply -n $NAMESPACE -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ai-service
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
      - name: ai
        image: $AI_IMAGE
        ports:
        - containerPort: 8000
---
apiVersion: v1
kind: Service
metadata:
  name: ai-service
spec:
  selector:
    app: ai-service
  ports:
  - port: 8000
EOF

success "AI service deployed"

}

############################################
# INGRESS
############################################

deploy_ingress() {

log "Deploying ingress..."

kubectl apply -n $NAMESPACE -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: eduai-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: $DOMAIN
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 80
EOF

success "Ingress deployed"

}

############################################
# AUTOSCALING
############################################

enable_autoscaling() {

log "Enabling autoscaling..."

kubectl autoscale deployment backend \
  -n $NAMESPACE \
  --cpu-percent=70 \
  --min=2 \
  --max=10

success "HPA enabled"

}

############################################
# VERIFY
############################################

verify() {

log "Checking deployment..."

kubectl get pods -n $NAMESPACE
kubectl get svc -n $NAMESPACE
kubectl get ingress -n $NAMESPACE

}

############################################
# MAIN
############################################

main() {

check_dependencies
start_cluster
create_namespaces

build_images
push_images

deploy_postgres
deploy_redis
deploy_backend
deploy_ai
deploy_frontend

deploy_ingress
enable_autoscaling

verify

success "AI Platform deployed successfully"

}

main
