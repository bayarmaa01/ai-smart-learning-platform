#!/bin/bash

# Fix frontend build issues
echo "🔧 Fixing frontend build..."

cd frontend

# Clean node modules and package-lock
rm -rf node_modules package-lock.json

# Install fresh dependencies
npm install

# Clear Vite cache
rm -rf .vite dist

# Try build with verbose output
npm run build

echo "✅ Frontend build complete!"
echo ""
echo "🚀 To start development:"
echo "npm run dev"
echo ""
echo "🔍 To check build output:"
echo "ls -la dist/"
