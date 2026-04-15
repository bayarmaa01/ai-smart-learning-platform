#!/bin/bash

echo "==============================================="
echo "  SYSTEM VERIFICATION CHECKS"
echo "==============================================="

# 1. KUBERNETES STATUS
echo "1. === KUBERNETES STATUS ==="
echo "Pods in eduai namespace:"
kubectl get pods -n eduai
echo -e "\nPods in monitoring namespace:"
kubectl get pods -n monitoring
echo -e "\nPods in eduai-argocd namespace:"
kubectl get pods -n eduai-argocd

# 2. DATABASE CHECKS
echo -e "\n2. === DATABASE STATUS ==="
echo "Testing PostgreSQL connection:"
kubectl exec -n eduai postgres-74b756c75f-x4mf2 -- psql -U postgres -d eduai -c "SELECT version();" 2>/dev/null || echo "FAILED"

echo -e "\nChecking tables exist:"
kubectl exec -n eduai postgres-74b756c75f-x4mf2 -- psql -U postgres -d eduai -c "\dt" 2>/dev/null || echo "FAILED"

echo -e "\nChecking users count:"
kubectl exec -n eduai postgres-74b756c75f-x4mf2 -- psql -U postgres -d eduai -c "SELECT COUNT(*) as user_count FROM users;" 2>/dev/null || echo "FAILED"

echo -e "\nChecking courses count:"
kubectl exec -n eduai postgres-74b756c75f-x4mf2 -- psql -U postgres -d eduai -c "SELECT COUNT(*) as course_count FROM courses;" 2>/dev/null || echo "FAILED"

# 3. BACKEND API CHECKS
echo -e "\n3. === BACKEND API STATUS ==="
echo "Health endpoint:"
curl -s http://localhost:4200/api/v1/health | jq . 2>/dev/null || echo "FAILED"

echo -e "\nAuth login test:"
curl -s -X POST http://localhost:4200/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@eduai.com","password":"Admin@1234"}' | jq . 2>/dev/null || echo "FAILED"

echo -e "\nCourses endpoint:"
curl -s http://localhost:4200/api/v1/courses | jq '.courses | length' 2>/dev/null || echo "FAILED"

# 4. FRONTEND CONNECTION
echo -e "\n4. === FRONTEND STATUS ==="
echo "Frontend accessibility:"
curl -s -o /dev/null -w "%{http_code}" http://localhost:3200

echo -e "\nFrontend API config test:"
kubectl exec -n eduai frontend-85b558dc7c-mpzm4 -- cat /usr/share/nginx/html/assets/index-*.js | grep -o "localhost:4200\|backend:5000" | head -1 2>/dev/null || echo "CONFIG CHECK FAILED"

# 5. AI INTEGRATION
echo -e "\n5. === AI INTEGRATION STATUS ==="
echo "AI health check:"
curl -s http://localhost:4200/api/v1/ai/health | jq . 2>/dev/null || echo "FAILED"

echo -e "\nAI chat test:"
curl -s -X POST http://localhost:4200/api/v1/chat \
  -H "Content-Type: application/json" \
  -d '{"message":"Hello AI"}' | jq '.success, .reply' 2>/dev/null || echo "FAILED"

# 6. SERVICES STATUS
echo -e "\n6. === SERVICES STATUS ==="
echo "Services in eduai namespace:"
kubectl get svc -n eduai

echo -e "\nPort-forward processes:"
ps aux | grep "kubectl port-forward" | grep -v grep || echo "NO PORT FORWARDS RUNNING"

# 7. RECENT LOGS
echo -e "\n7. === RECENT LOGS ==="
echo "Backend logs (last 10 lines):"
kubectl logs -n eduai deployment/backend --tail=10 2>/dev/null || echo "NO LOGS"

echo -e "\nFrontend logs (last 5 lines):"
kubectl logs -n eduai deployment/frontend --tail=5 2>/dev/null || echo "NO LOGS"

echo -e "\nPostgres logs (last 5 lines):"
kubectl logs -n eduai postgres-74b756c75f-x4mf2 --tail=5 2>/dev/null || echo "NO LOGS"

echo -e "\n==============================================="
echo "  VERIFICATION COMPLETE"
echo "==============================================="
