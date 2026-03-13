#!/bin/bash

# Rebuild frontend with registration fixes
echo "🔨 Rebuilding Frontend with Registration Fixes..."

cd frontend

# Rebuild frontend
echo "🔨 Building frontend..."
npm run build

if [ $? -eq 0 ]; then
    echo "✅ Frontend build successful!"
    
    # Restart frontend container
    echo "🔄 Restarting frontend container..."
    cd ..
    docker compose restart frontend
    
    echo "✅ Frontend rebuilt and restarted!"
    echo ""
    echo "🌐 Test registration:"
    echo "1. Open http://localhost:3000"
    echo "2. Go to registration page"
    echo "3. Fill all fields including role selection"
    echo "4. Submit form"
else
    echo "❌ Frontend build failed!"
    exit 1
fi
