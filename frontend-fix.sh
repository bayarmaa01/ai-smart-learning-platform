#!/bin/bash

echo "==============================================="
echo "  FRONTEND API CONFIG FIX"
echo "==============================================="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { printf "${GREEN}[INFO]${NC} %s\n" "$1"; }
warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$1"; }

# 1. REBUILD FRONTEND IMAGE
echo "1. Rebuilding frontend image with fixed API config..."
docker build -t eduai-frontend:latest ./frontend || {
    error "Failed to build frontend image"
    exit 1
}

# 2. LOAD INTO MINIKUBE
echo "2. Loading frontend image into Minikube..."
minikube image load eduai-frontend:latest || {
    error "Failed to load image into Minikube"
    exit 1
}

# 3. UPDATE FRONTEND DEPLOYMENT
echo "3. Updating frontend deployment..."
kubectl set image deployment/frontend frontend=eduai-frontend:latest -n eduai || {
    error "Failed to update frontend deployment"
    exit 1
}

# 4. WAIT FOR ROLLOUT
echo "4. Waiting for frontend rollout..."
kubectl rollout status deployment/frontend -n eduai --timeout=60s || {
    warn "Frontend rollout timed out, but may still be completing"
}

# 5. RESTART PORT FORWARDS
echo "5. Restarting port forwards..."
pkill -f "kubectl port-forward" || true
sleep 2

# Start port forwards in background
kubectl port-forward -n eduai svc/frontend 3200:3000 &
kubectl port-forward -n eduai svc/backend 4200:5000 &
kubectl port-forward -n eduai svc/backend 5200:5000 &
kubectl port-forward -n monitoring svc/grafana 3004:3000 &

sleep 3

# 6. TEST FRONTEND ACCESS
echo "6. Testing frontend access..."
FRONTEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3200)
if [ "$FRONTEND_STATUS" = "200" ]; then
    log "Frontend accessible: http://localhost:3200"
else
    error "Frontend not accessible (status: $FRONTEND_STATUS)"
fi

# 7. TEST BACKEND API
echo "7. Testing backend API..."
BACKEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:4200/api/v1/health)
if [ "$BACKEND_STATUS" = "200" ]; then
    log "Backend API accessible: http://localhost:4200"
else
    error "Backend API not accessible (status: $BACKEND_STATUS)"
fi

echo ""
echo "==============================================="
echo "  FRONTEND FIX COMPLETE"
echo "==============================================="
echo "Frontend:   http://localhost:3200"
echo "Backend:    http://localhost:4200"
echo "Login:      admin@eduai.com / Admin@1234"
echo "==============================================="
