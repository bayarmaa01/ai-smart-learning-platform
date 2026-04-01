#!/bin/bash

set -e

echo "🚨 EMERGENCY PLATFORM FIX"
echo "========================"
echo ""

echo "🔧 STEP 1: Restart Minikube Cluster..."
minikube stop -p eduai-cluster || true
minikube delete -p eduai-cluster || true
minikube start -p eduai-cluster --cpus=2 --memory=4096
echo "✅ Minikube restarted"

echo ""
echo "🔧 STEP 2: Set kubectl context..."
kubectl config use-context eduai-cluster
echo "✅ Context set"

echo ""
echo "🔧 STEP 3: Deploy Full Platform..."
./deploy-full-platform.sh

echo ""
echo "🔧 STEP 4: Fix Cloudflare Tunnel..."
./fix-cloudflare-tunnel.sh

echo ""
echo "🔧 STEP 5: Test All Services..."
./test-ingress.sh

echo ""
echo "🔧 STEP 6: Check Database Issues..."
echo "Checking backend logs for course issues..."
kubectl logs -n eduai -l app=backend --tail=20

echo ""
echo "🎯 PLATFORM STATUS:"
echo "=================="
echo "✅ Minikube: Running"
echo "✅ Services: Deployed"
echo "✅ Ingress: Configured"
echo "✅ Tunnel: Fixed"
echo ""
echo "📱 Access URLs:"
echo "Frontend: https://ailearn.duckdns.org"
echo "Backend:  https://ailearn.duckdns.org/api"
echo "Local:    http://localhost:3000 (port-forward)"
echo ""
echo "🔍 If courses still not visible:"
echo "1. Check database connection: kubectl logs -n eduai -l app=backend"
echo "2. Check frontend API calls: kubectl logs -n eduai -l app=frontend"
echo "3. Restart services: kubectl rollout restart deployment/frontend deployment/backend -n eduai"
