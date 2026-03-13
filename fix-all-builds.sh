#!/bin/bash

# Fix all build issues and rebuild
echo "🔧 Fixing all build issues..."

# Fix frontend
echo "📱 Fixing frontend..."
cd frontend
rm -rf node_modules package-lock.json .vite dist
npm install
npm run build
if [ $? -eq 0 ]; then
    echo "✅ Frontend build successful!"
else
    echo "❌ Frontend build failed!"
    exit 1
fi

cd ..

# Build all services
echo "🐳 Building all services..."
docker compose down 2>/dev/null || true
docker compose build --no-cache

if [ $? -eq 0 ]; then
    echo "✅ All services built successfully!"
    echo ""
    echo "🚀 To start all services:"
    echo "docker compose up -d"
    echo ""
    echo "🔍 To check logs:"
    echo "docker compose logs -f"
else
    echo "❌ Build failed!"
    exit 1
fi

echo "🎉 All fixes complete!"
