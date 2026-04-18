#!/bin/bash

# EduAI Platform - System Rebuild Script
# This script rebuilds the entire system with all critical fixes applied

set -e

echo "🔥 EduAI Platform - System Rebuild Script"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
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
print_status "Step 3: Building and starting backend..."
docker-compose up -d --build backend

# Wait for backend to be ready
print_status "Waiting for backend to be ready..."
sleep 15

# Step 4: Build and start frontend
print_status "Step 4: Building and starting frontend..."
docker-compose up -d --build frontend

# Step 5: Start nginx reverse proxy
print_status "Step 5: Starting nginx reverse proxy..."
docker-compose up -d nginx

# Step 6: Start monitoring
print_status "Step 6: Starting monitoring services..."
docker-compose up -d prometheus grafana

# Step 7: Verify system health
print_status "Step 7: Verifying system health..."

echo "Checking service health..."
sleep 10

# Check if services are running
services=("eduai-postgres" "eduai-redis" "eduai-ollama" "eduai-backend" "eduai-frontend" "eduai-nginx" "eduai-prometheus" "eduai-grafana")

for service in "${services[@]}"; do
    if docker ps --format "table {{.Names}}" | grep -q "$service"; then
        print_status "✅ $service is running"
    else
        print_error "❌ $service is not running"
    fi
done

# Step 8: Test API endpoints
print_status "Step 8: Testing API endpoints..."

# Test backend health
if curl -f http://localhost:80/api/v1/health > /dev/null 2>&1; then
    print_status "✅ Backend API is accessible"
else
    print_warning "⚠️ Backend API might not be fully ready yet"
fi

# Test frontend
if curl -f http://localhost:80/ > /dev/null 2>&1; then
    print_status "✅ Frontend is accessible"
else
    print_warning "⚠️ Frontend might not be fully ready yet"
fi

# Step 9: Display access information
print_status "Step 9: System Access Information"

echo ""
echo "🌐 Access URLs:"
echo "================"
echo "Main Application: http://localhost:80"
echo "Backend API: http://localhost:80/api/v1"
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
print_warning "⚠️ If you see any errors, check the logs with: docker-compose logs -f"

echo ""
echo "🚀 Your EduAI Platform should now be running at http://localhost:80"
echo "   The system includes all critical fixes for authentication, routing, and API integration."
