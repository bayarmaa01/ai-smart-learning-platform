#!/bin/bash

echo "=== Test Frontend Proxy to Backend ==="

# Test 1: Frontend health
echo "1. Testing frontend access..."
curl -I http://localhost:3200/ 2>/dev/null | head -5

echo ""

# Test 2: Backend health through proxy
echo "2. Testing backend health through frontend proxy..."
curl -I http://localhost:3200/api/v1/health 2>/dev/null | head -5

echo ""

# Test 3: Direct backend health
echo "3. Testing direct backend health..."
curl -I http://localhost:4200/api/v1/health 2>/dev/null | head -5

echo ""

# Test 4: Auth register through proxy
echo "4. Testing auth register through frontend proxy..."
curl -X POST http://localhost:3200/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"123456","firstName":"Test","lastName":"User","role":"student"}' \
  -w "\nHTTP Status: %{http_code}\n" \
  2>/dev/null

echo ""

# Test 5: Auth register direct to backend
echo "5. Testing auth register direct to backend..."
curl -X POST http://localhost:4200/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"123456","firstName":"Test","lastName":"User","role":"student"}' \
  -w "\nHTTP Status: %{http_code}\n" \
  2>/dev/null

echo ""
echo "=== Proxy Test Complete ==="
