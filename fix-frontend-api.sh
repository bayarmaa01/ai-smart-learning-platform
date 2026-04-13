#!/bin/bash

# Fix frontend API configuration and rebuild
echo "🔧 Fixing Frontend API Configuration..."

cd frontend

# Create .env file with correct ports
cat > .env << EOF
VITE_API_URL=http://localhost:5001/api/v1
VITE_AI_URL=http://localhost:8001
VITE_SOCKET_URL=http://localhost:5001
EOF

echo "✅ Created .env file with correct ports"

# Rebuild frontend
echo "🔨 Rebuilding frontend..."
npm run build

if [ $? -eq 0 ]; then
    echo "✅ Frontend build successful!"
    echo ""
    echo "🔄 Restarting frontend container..."
    cd ..
    docker compose restart frontend
    
    echo "✅ Frontend restarted with correct API URL!"
else
    echo "❌ Frontend build failed!"
    exit 1
fi

echo ""
echo "🌐 Updated Configuration:"
echo "  API URL: http://localhost:5001/api/v1"
echo "  AI URL: http://localhost:8001"
echo "  Socket URL: http://localhost:5001"
echo ""
echo "🧪 Test the API:"
echo "curl -f http://localhost:5001/api/v1/health"
# =============================================================================
# Fix Frontend API Configuration
# Rebuilds frontend with correct API URL
# =============================================================================

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

echo "==============================================="
echo "  FIX FRONTEND API CONFIGURATION"
echo "==============================================="
echo ""

# Check if we're in the right directory
if [ ! -f "frontend/package.json" ]; then
    error "frontend/package.json not found. Please run from project root."
    exit 1
fi

# Update API configuration
log "Updating frontend API configuration..."
cat > frontend/src/services/api.js << 'EOF'
import axios from 'axios';
import toast from 'react-hot-toast';

const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:4200/api/v1';

const api = axios.create({
  baseURL: API_BASE_URL,
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json',
  },
});

api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('accessToken');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    const tenantId = localStorage.getItem('tenantId');
    if (tenantId) {
      config.headers['X-Tenant-ID'] = tenantId;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem('accessToken');
      localStorage.removeItem('tenantId');
      window.location.href = '/login';
    }
    const message = error.response?.data?.error?.message || error.message;
    toast.error(message);
    return Promise.reject(error);
  }
);

export default api;
EOF

success "Frontend API configuration updated"

# Create environment file
log "Creating environment file..."
cat > frontend/.env.production << EOF
VITE_API_URL=http://localhost:4200/api/v1
VITE_FRONTEND_URL=http://localhost:3200
EOF

success "Environment file created"

# Rebuild frontend
log "Rebuilding frontend..."
cd frontend

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    log "Installing dependencies..."
    npm install
fi

# Build frontend
log "Building frontend..."
npm run build

success "Frontend rebuilt successfully"

cd ..

# Update frontend deployment
log "Updating frontend deployment..."
docker build -t eduai-frontend:latest -f frontend/Dockerfile frontend/

success "Frontend image built"

# Deploy updated frontend
log "Deploying updated frontend..."
kubectl apply -f k8s/frontend-deployment-fixed.yaml

success "Frontend deployed"

echo ""
echo "==============================================="
echo "  FRONTEND API FIX COMPLETE"
echo "==============================================="
echo ""
echo "The frontend has been rebuilt with the correct API configuration:"
echo "  Frontend: http://localhost:3200"
echo "  Backend API: http://localhost:4200/api/v1"
echo ""
echo "Please wait a few moments for the deployment to complete, then:"
echo "1. Refresh your browser at http://localhost:3200"
echo "2. Try registering/logging in again"
echo ""
echo "The 405 errors should now be resolved!"
echo ""
