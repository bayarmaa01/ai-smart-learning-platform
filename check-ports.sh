#!/bin/bash

# Check and fix port conflicts
echo "🔍 Checking port conflicts..."

# Check port 9000
echo "Checking port 9000..."
if lsof -i :9000 > /dev/null 2>&1; then
    echo "❌ Port 9000 is in use:"
    lsof -i :9000
    echo ""
    echo "🔧 Stopping services using port 9000..."
    # Kill processes using port 9000
    sudo lsof -ti :9000 | xargs sudo kill -9 2>/dev/null || true
    sleep 2
else
    echo "✅ Port 9000 is free"
fi

# Check other common ports
for port in 3000 5000 8000 5432 6379 9090 3001; do
    if lsof -i :$port > /dev/null 2>&1; then
        echo "⚠️  Port $port is in use:"
        lsof -i :$port
    else
        echo "✅ Port $port is free"
    fi
done

echo ""
echo "🚀 Now you can run:"
echo "docker compose up -d"
