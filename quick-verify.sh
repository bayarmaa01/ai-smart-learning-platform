#!/bin/bash

echo "QUICK SYSTEM VERIFICATION"
echo "========================"

# Kubernetes Pods
echo "1. PODS STATUS:"
kubectl get pods -n eduai --no-headers | awk '{print $1,$2,$3}' | while read pod status rest; do
  if [[ "$status" == "Running" ]]; then echo "  $pod: OK"; else echo "  $pod: ERROR ($status)"; fi
done

# Database Tables
echo -e "\n2. DATABASE:"
tables=$(kubectl exec -n eduai postgres-74b756c75f-x4mf2 -- psql -U postgres -d eduai -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public'" 2>/dev/null | tr -d ' ')
echo "  Tables: $tables"

# API Health
echo -e "\n3. API ENDPOINTS:"
health=$(curl -s http://localhost:4200/api/v1/health | jq -r '.status' 2>/dev/null)
echo "  Health: $health"

login=$(curl -s -X POST http://localhost:4200/api/v1/auth/login -H "Content-Type: application/json" -d '{"email":"admin@eduai.com","password":"Admin@1234"}' | jq -r '.success' 2>/dev/null)
echo "  Login: $login"

courses=$(curl -s http://localhost:4200/api/v1/courses | jq '.courses | length' 2>/dev/null)
echo "  Courses: $courses"

# AI Status
echo -e "\n4. AI INTEGRATION:"
ai_health=$(curl -s http://localhost:4200/api/v1/ai/health | jq -r '.status' 2>/dev/null)
echo "  AI Health: $ai_health"

ai_chat=$(curl -s -X POST http://localhost:4200/api/v1/chat -H "Content-Type: application/json" -d '{"message":"test"}' | jq -r '.success' 2>/dev/null)
echo "  AI Chat: $ai_chat"

# Frontend
echo -e "\n5. FRONTEND:"
frontend=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3200)
echo "  Frontend: $frontend"

echo -e "\n========================"
echo "VERIFICATION COMPLETE"
