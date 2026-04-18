#!/bin/bash

# EduAI Platform - Windows/WSL2 Compatible System Rebuild Script
# This script rebuilds entire system with all critical fixes applied

set -e

echo "🔥 EduAI Platform - Windows/WSL2 System Rebuild"
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Step 1: Clean up existing containers and volumes
print_status "Step 1: Cleaning up existing containers and volumes..."
docker.exe compose down -v 2>/dev/null || docker compose down -v 2>/dev/null || {
    print_error "Docker Compose not found. Please ensure Docker Desktop is running with WSL2 integration."
    exit 1
}

# Step 2: Rebuild database with updated schema
print_status "Step 2: Rebuilding database with updated schema..."
docker.exe compose up -d postgres redis ollama 2>/dev/null || docker compose up -d postgres redis ollama

# Wait for database to be ready
print_status "Waiting for PostgreSQL to be ready..."
sleep 10

# Step 3: Build and start backend
print_status "Step 3: Building and starting backend..."
docker.exe compose up -d --build backend 2>/dev/null || docker compose up -d --build backend

# Wait for backend to be ready
print_status "Waiting for backend to be ready..."
sleep 15

# Step 4: Build and start AI service
print_status "Step 4: Building and starting AI service..."
docker.exe compose up -d --build ai-service 2>/dev/null || docker compose up -d --build ai-service

# Wait for AI service to be ready
print_status "Waiting for AI service to be ready..."
sleep 10

# Step 5: Build and start frontend
print_status "Step 5: Building and starting frontend..."
docker.exe compose up -d --build frontend 2>/dev/null || docker compose up -d --build frontend

# Step 6: Start monitoring
print_status "Step 6: Starting monitoring services..."
docker.exe compose up -d prometheus grafana 2>/dev/null || docker compose up -d prometheus grafana

# Step 7: Verify system health
print_status "Step 7: Verifying system health..."

echo "Checking service health..."
sleep 10

# Check if services are running
services=("eduai-postgres" "eduai-redis" "eduai-ollama" "eduai-backend" "eduai-ai-service" "eduai-frontend" "eduai-prometheus" "eduai-grafana")

for service in "${services[@]}"; do
    if docker.exe ps --format "table {{.Names}}" 2>/dev/null | grep -q "$service" || docker ps --format "table {{.Names}}" | grep -q "$service"; then
        print_status "✅ $service is running"
    else
        print_error "❌ $service is not running"
    fi
done

# Step 8: Test API endpoints
print_status "Step 8: Testing API endpoints..."

# Test backend health
print_status "Testing backend health endpoint..."
if curl.exe -s -f http://localhost:4000/api/v1/health > /dev/null 2>&1 || curl -s -f http://localhost:4000/api/v1/health > /dev/null; then
    print_status "✅ Backend health endpoint working"
else
    print_warning "⚠️ Backend API might not be fully ready yet"
fi

# Test AI service
print_status "Testing AI service endpoint..."
if curl.exe -s -f http://localhost:5000/health > /dev/null 2>&1 || curl -s -f http://localhost:5000/health > /dev/null; then
    print_status "✅ AI service health endpoint working"
else
    print_warning "⚠️ AI service might not be fully ready yet"
fi

# Test frontend
print_status "Testing frontend main page..."
if curl.exe -s -f http://localhost:3000/ > /dev/null 2>&1 || curl -s -f http://localhost:3000/ > /dev/null; then
    print_status "✅ Frontend is accessible"
else
    print_warning "⚠️ Frontend might not be fully ready yet"
fi

# Step 9: Display access information
print_status "Step 9: System Access Information"

echo ""
echo "🌐 Access URLs:"
echo "================"
echo "Main Application: http://localhost:3000"
echo "Backend API: http://localhost:4000/api/v1"
echo "AI Service: http://localhost:5000"
echo "Prometheus: http://localhost:9090"
echo "Grafana: http://localhost:3001"
echo ""

echo "🔑 Default Credentials:"
echo "======================"
echo "Grafana: admin / admin"
echo ""

echo "📝 Demo Accounts (after registration):"
echo "===================================="
echo "Student: student@eduai.com / Student@1234"
echo "Instructor: instructor@eduai.com / Instructor@1234"
echo ""

echo "🔍 Useful Commands:"
echo "=================="
echo "View logs: docker.exe compose logs -f [service-name]"
echo "Stop all: docker.exe compose down"
echo "Restart: docker.exe compose restart [service-name]"
echo ""

print_status "✅ System rebuild completed!"
print_warning "⚠️ If you see any errors, check logs with: docker.exe compose logs -f"

echo ""
echo "🚀 Your EduAI Platform should now be running with your custom ports:"
echo "   Frontend: http://localhost:3000"
echo "   Backend: http://localhost:4000/api/v1"
echo "   AI Service: http://localhost:5000"
echo "   Monitoring: http://localhost:9090 (Prometheus), http://localhost:3001 (Grafana)"
