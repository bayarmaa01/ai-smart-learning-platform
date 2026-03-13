#!/bin/bash

# Fix frontend API configuration and rebuild
echo "🔧 Fixing Frontend API Configuration..."

cd frontend

# Create .env file with correct ports
cat > .env << EOF
VITE_API_URL=http://localhost:5001/api/v1
VITE_AI_URL=http://localhost:8001
VITE_SOCKET_URL=http://localhost:5001
EOF

echo "✅ Created .env file with correct ports"

# Rebuild frontend
echo "🔨 Rebuilding frontend..."
npm run build

if [ $? -eq 0 ]; then
    echo "✅ Frontend build successful!"
    echo ""
    echo "🔄 Restarting frontend container..."
    cd ..
    docker compose restart frontend
    
    echo "✅ Frontend restarted with correct API URL!"
else
    echo "❌ Frontend build failed!"
    exit 1
fi

echo ""
echo "🌐 Updated Configuration:"
echo "  API URL: http://localhost:5001/api/v1"
echo "  AI URL: http://localhost:8001"
echo "  Socket URL: http://localhost:5001"
echo ""
echo "🧪 Test the API:"
echo "curl -f http://localhost:5001/api/v1/health"
