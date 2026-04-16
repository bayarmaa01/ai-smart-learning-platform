#!/bin/bash

echo "Fixing database migration issues..."

# Stop all containers
echo "Stopping containers..."
docker compose down

# Remove the database volume to start fresh
echo "Removing database volume..."
docker volume rm ai-smart-learning-platform_postgres_data

# Remove the backend container to force rebuild
echo "Removing backend container..."
docker rmi ai-smart-learning-platform-backend 2>/dev/null || true

# Start services again
echo "Starting services..."
docker compose up -d --build

# Wait for database to be ready
echo "Waiting for database to be ready..."
sleep 10

# Check backend logs
echo "Checking backend logs..."
docker logs eduai-backend --tail 20

echo "Database reset complete!"
echo "Backend should now start successfully."
echo "Frontend should be accessible at: http://localhost:3200"
echo "Backend should be accessible at: http://localhost:4200"
