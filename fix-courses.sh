#!/bin/bash

set -e

echo "📚 COURSE VISIBILITY FIX"
echo "======================="
echo ""

echo "🔧 STEP 1: Check Backend Database Connection..."
kubectl get pods -n eduai | grep backend
echo ""

echo "🔧 STEP 2: Check Backend Logs for Database Issues..."
kubectl logs -n eduai -l app=backend --tail=30 | grep -E "(database|DB|connection|error|course)" || echo "No database errors found"
echo ""

echo "🔧 STEP 3: Restart Backend Service..."
kubectl rollout restart deployment/backend -n eduai
echo "✅ Backend restarted"

echo "🔧 STEP 4: Wait for Backend to be Ready..."
kubectl wait --for=condition=Ready pods -n eduai -l app=backend --timeout=120s
echo "✅ Backend ready"

echo "🔧 STEP 5: Check Frontend API Connection..."
kubectl logs -n eduai -l app=frontend --tail=20 | grep -E "(api|fetch|course|error)" || echo "No frontend API errors found"
echo ""

echo "🔧 STEP 6: Restart Frontend Service..."
kubectl rollout restart deployment/frontend -n eduai
echo "✅ Frontend restarted"

echo "🔧 STEP 7: Wait for Frontend to be Ready..."
kubectl wait --for=condition=Ready pods -n eduai -l app=frontend --timeout=120s
echo "✅ Frontend ready"

echo ""
echo "🧪 STEP 8: Test API Endpoints..."
MINIKUBE_IP=$(minikube ip -p eduai-cluster 2>/dev/null || echo "192.168.58.2")

echo "Testing backend API..."
curl -H "Host: ailearn.duckdns.org" "http://$MINIKUBE_IP/api/courses" -v --max-time 10 || echo "❌ Backend API not accessible"

echo ""
echo "Testing frontend..."
curl -H "Host: ailearn.duckdns.org" "http://$MINIKUBE_IP/" -I --max-time 10 || echo "❌ Frontend not accessible"

echo ""
echo "📊 Database Check Commands:"
echo "=========================="
echo "# Check database pod:"
echo "kubectl get pods -n eduai | grep -E "(postgres|mysql|db)"
echo ""
echo "# Check database logs:"
echo "kubectl logs -n eduai -l app=database --tail=20"
echo ""
echo "# Access database (if postgres):"
echo "kubectl exec -it -n eduai deployment/postgres -- psql -U postgres -d eduai"
echo ""
echo "# Check course tables:"
echo "\\c eduai"
echo "\\dt"
echo "SELECT * FROM courses LIMIT 5;"

echo ""
echo "🎯 If courses still not visible:"
echo "1. Database may be empty - run database migrations"
echo "2. Check if teacher role is properly assigned"
echo "3. Verify course creation API is working"
echo "4. Check frontend API endpoint configuration"
