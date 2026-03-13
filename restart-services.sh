#!/bin/bash

# Restart all services with port fixes
echo "🔄 Restarting EduAI Platform services..."

# Stop all services
echo "⏹️  Stopping existing services..."
docker compose down

# Clean up any orphaned containers
echo "🧹 Cleaning up orphaned containers..."
docker container prune -f

# Start services
echo "🚀 Starting all services..."
docker compose up -d

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 30

# Check service status
echo "📊 Checking service status..."
docker compose ps

echo ""
echo "🎉 Services started!"
echo ""
echo "🌐 Access URLs:"
echo "  Frontend: http://localhost:3000"
echo "  Backend API: http://localhost:5000"
echo "  AI Service: http://localhost:8000"
echo "  MinIO Console: http://localhost:9003"
echo "  MinIO API: http://localhost:9002"
echo "  Grafana: http://localhost:3001"
echo "  Prometheus: http://localhost:9090"
echo "  PostgreSQL: localhost:5433 (external), postgres:5432 (internal)"
echo "  Redis: localhost:6379"
echo "  Elasticsearch: http://localhost:9200"
echo ""
echo "📋 To view logs:"
echo "docker compose logs -f"
echo ""
echo "🛑 To stop services:"
echo "docker compose down"
