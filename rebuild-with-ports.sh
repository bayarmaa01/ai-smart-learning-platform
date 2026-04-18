#!/bin/bash

# EduAI Platform - Rebuild Script with Custom Port Configuration
# Frontend: 3000, Backend: 4000, AI: 5000, Grafana: 3001, Prometheus: 9090

set -e

echo "🚀 EduAI Platform - Rebuild with Custom Ports"
echo "=============================================="
echo "Frontend: http://localhost:3000"
echo "Backend API: http://localhost:4000/api/v1"
echo "AI Service: http://localhost:5000"
echo "Grafana: http://localhost:3001"
echo "Prometheus: http://localhost:9090"
echo ""

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
docker-compose down -v
docker system prune -f

# Step 2: Rebuild database with updated schema
print_status "Step 2: Rebuilding database with updated schema..."
docker-compose up -d postgres redis ollama

# Wait for database to be ready
print_status "Waiting for PostgreSQL to be ready..."
sleep 10

# Step 3: Build and start backend
print_status "Step 3: Building and starting backend (port 4000)..."
docker-compose up -d --build backend

# Wait for backend to be ready
print_status "Waiting for backend to be ready..."
sleep 15

# Step 4: Build and start AI service
print_status "Step 4: Building and starting AI service (port 5000)..."
docker-compose up -d --build ai-service

# Wait for AI service to be ready
print_status "Waiting for AI service to be ready..."
sleep 10

# Step 5: Build and start frontend
print_status "Step 5: Building and starting frontend (port 3000)..."
docker-compose up -d --build frontend

# Step 6: Start monitoring
print_status "Step 6: Starting monitoring services..."
docker-compose up -d prometheus grafana

# Step 7: Verify system health
print_status "Step 7: Verifying system health..."

echo "Checking service health..."
sleep 10

# Check if services are running
services=("eduai-postgres:5432" "eduai-redis:6379" "eduai-ollama:11434" "eduai-backend:4000" "eduai-ai-service:5000" "eduai-frontend:3000" "eduai-prometheus:9090" "eduai-grafana:3001")

for service_info in "${services[@]}"; do
    service_name=$(echo $service_info | cut -d: -f1)
    port=$(echo $service_info | cut -d: -f2)
    
    if docker ps --format "table {{.Names}}" | grep -q "$service_name"; then
        print_status "✅ $service_name is running"
        
        # Test port accessibility
        if nc -z localhost $port 2>/dev/null; then
            print_status "✅ Port $port is accessible"
        else
            print_warning "⚠️ Port $port might not be accessible from host"
        fi
    else
        print_error "❌ $service_name is not running"
    fi
done

# Step 8: Test API endpoints
print_status "Step 8: Testing API endpoints..."

# Test backend health
print_test "Testing backend health endpoint..."
if curl -s -f http://localhost:4000/api/v1/health > /dev/null; then
    print_status "✅ Backend health endpoint working"
else
    print_warning "⚠️ Backend health endpoint might not be ready yet"
fi

# Test AI service
print_test "Testing AI service health endpoint..."
if curl -s -f http://localhost:5000/health > /dev/null; then
    print_status "✅ AI service health endpoint working"
else
    print_warning "⚠️ AI service health endpoint might not be ready yet"
fi

# Test frontend
print_test "Testing frontend main page..."
if curl -s -f http://localhost:3000/ > /dev/null; then
    print_status "✅ Frontend is accessible"
else
    print_warning "⚠️ Frontend might not be fully ready yet"
fi

# Step 9: Display access information
print_status "Step 9: System Access Information"

echo ""
echo "🌐 Access URLs:"
echo "================"
echo "Frontend (React App): http://localhost:3000"
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
echo "View logs: docker-compose logs -f [service-name]"
echo "Stop all: docker-compose down"
echo "Restart: docker-compose restart [service-name]"
echo ""

print_status "✅ System rebuild completed!"
print_warning "⚠️ If you see any errors, check logs with: docker-compose logs -f"

echo ""
echo "🚀 Your EduAI Platform is running with custom ports:"
echo "   Frontend: http://localhost:3000"
echo "   Backend: http://localhost:4000/api/v1"
echo "   AI Service: http://localhost:5000"
echo "   Monitoring: http://localhost:9090 (Prometheus), http://localhost:3001 (Grafana)"
