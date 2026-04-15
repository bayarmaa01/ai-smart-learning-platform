#!/bin/bash

echo "==============================================="
echo "  FIX PLATFORM ISSUES"
echo "==============================================="

# 1. Test backend API endpoints directly
echo "1. Testing backend API endpoints..."
echo "Testing health endpoint:"
curl -s http://localhost:4200/api/v1/health | jq .

echo -e "\nTesting auth endpoint:"
curl -s -X POST http://localhost:4200/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@eduai.com","password":"Admin@1234"}' | jq .

# 2. Fix monitoring services
echo -e "\n2. Restarting monitoring services..."
kubectl delete pod -n monitoring prometheus-84dffd5cf5-s5c67 --ignore-not-found=true
kubectl delete pod -n monitoring alertmanager-7bc58fbbf7-nrrpq --ignore-not-found=true

# 3. Fix ArgoCD CRDs 
echo -e "\n3. Installing ArgoCD CRDs..."
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --validate=false

# 4. Restart ArgoCD pods
echo -e "\n4. Restarting ArgoCD pods..."
kubectl delete pod -n eduai-argocd --all --ignore-not-found=true

# 5. Wait for services to be ready
echo -e "\n5. Waiting for services to be ready..."
sleep 30

# 6. Check all pod statuses
echo -e "\n6. Checking pod statuses..."
echo "eduai namespace:"
kubectl get pods -n eduai

echo -e "\nmonitoring namespace:"
kubectl get pods -n monitoring

echo -e "\neduai-argocd namespace:"
kubectl get pods -n eduai-argocd

# 7. Test all endpoints
echo -e "\n7. Testing all endpoints..."
echo "Frontend (3200):"
curl -s -I http://localhost:3200 | head -1

echo "Backend health (4200):"
curl -s -I http://localhost:4200/api/v1/health | head -1

echo "AI Chat (5200):"
curl -s -I http://localhost:5200/api/chat | head -1

echo "Grafana (3004):"
curl -s -I http://localhost:3004 | head -1

echo "Prometheus (9093):"
curl -s -I http://localhost:9093 | head -1

echo "ArgoCD (18080):"
curl -s -I http://localhost:18080 | head -1

echo -e "\n==============================================="
echo "  FIX COMPLETE"
echo "==============================================="
