#!/bin/bash

# Debug registration error from browser
echo "🔍 Debugging Registration Error..."

echo "1. Checking backend logs..."
docker compose logs --tail=20 backend

echo ""
echo "2. Testing exact same request format as frontend..."
curl -s -X POST http://localhost:5000/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{
    "firstName": "Test",
    "lastName": "User", 
    "email": "test@example.com",
    "password": "TestUser123!",
    "confirmPassword": "TestUser123!",
    "role": "student",
    "agreeTerms": true
  }' | jq '.' || echo "Request failed"

echo ""
echo "3. Checking if role field is being sent..."
echo "The frontend should be sending: \"role\": \"student\" or \"role\": \"admin\""
echo ""
echo "4. Common 400 error causes:"
echo "  - Missing role field"
echo "  - Invalid role value" 
echo "  - Missing required fields"
echo "  - Password doesn't meet requirements"
echo ""
echo "5. To see exact browser request:"
echo "  - Open browser DevTools (F12)"
echo "  - Go to Network tab"
echo "  - Try registering"
echo "  - Check the POST /api/v1/auth/register request"
echo "  - Look at Request Payload and Response"
