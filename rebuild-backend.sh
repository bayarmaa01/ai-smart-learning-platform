#!/bin/bash

# Rebuild backend to load new health endpoint
echo "🔨 Rebuilding backend..."

# Stop backend
echo "⏹️  Stopping backend..."
docker compose stop backend

# Rebuild backend
echo "🔨 Building backend image..."
docker compose build backend

# Start backend
echo "🚀 Starting backend..."
docker compose up -d backend

# Wait for backend
echo "⏳ Waiting for backend to start..."
sleep 15

# Test endpoints
echo "🧪 Testing endpoints..."
echo "Testing /health:"
curl -f http://localhost:5001/health && echo " ✅" || echo " ❌"

echo "Testing /api/v1/health:"
curl -f http://localhost:5001/api/v1/health && echo " ✅" || echo " ❌"

echo "Testing registration:"
curl -X POST http://localhost:5001/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"email":"test2@example.com","password":"Test123!","firstName":"Test2","lastName":"User"}' \
  -w "\nStatus: %{http_code}\n" || echo " ❌"

echo ""
echo "✅ Backend rebuilt with new health endpoint!"
echo ""
echo "🌐 Browser Testing:"
echo "1. Open http://localhost:3000"
echo "2. Press Ctrl+F5 to hard refresh"
echo "3. Try registration again"
