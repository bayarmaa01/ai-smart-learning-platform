#!/bin/bash

echo "==============================================="
echo "  FIX AUTO-VERSIONING AND API CONFIGURATION"
echo "==============================================="
echo ""

cd frontend

echo "1. Rebuilding frontend with disabled auto-versioning..."
npm run build

if [ $? -eq 0 ]; then
    echo "   Frontend build successful!"
else
    echo "   Frontend build failed!"
    exit 1
fi

cd ..

echo "2. Rebuilding Docker image..."
docker build -t eduai-frontend:latest -f frontend/Dockerfile frontend/

if [ $? -eq 0 ]; then
    echo "   Docker image built successfully!"
else
    echo "   Docker image build failed!"
    exit 1
fi

echo "3. Restarting frontend deployment..."
kubectl rollout restart deployment/frontend -n eduai

echo "4. Waiting for deployment to complete..."
kubectl rollout status deployment/frontend -n eduai --timeout=120s

echo ""
echo "==============================================="
echo "  FIX COMPLETE"
echo "==============================================="
echo ""
echo "Changes made:"
echo "  - Auto-version checking disabled (no more constant refreshes)"
echo "  - Frontend rebuilt with correct API configuration"
echo "  - Frontend deployment restarted"
echo ""
echo "Next steps:"
echo "  1. Wait 30 seconds for deployment to complete"
echo "  2. Clear browser cache (Ctrl+F5 or Incognito mode)"
echo "  3. Try logging in at http://localhost:3200"
echo ""
echo "The 405 errors should now be resolved!"
