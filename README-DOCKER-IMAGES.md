# Docker Images Build Guide - AI Smart Learning Platform

## Overview

This guide helps you build and push Docker images for your AI Smart Learning Platform using your Docker Hub username `bayarmaa`.

## 🚀 Quick Start

### Build All Images
```bash
# Make script executable
chmod +x build-docker-images.sh

# Build all images
./build-docker-images.sh build
```

### Build and Push All Images
```bash
# Build and push to Docker Hub
./build-docker-images.sh all
```

## 📦 Docker Images

### Frontend Image
- **Name**: `bayarmaa/eduai-frontend:latest`
- **Base**: `nginx:alpine`
- **Port**: 80
- **Features**:
  - React build optimization
  - Nginx configuration
  - Gzip compression
  - Security headers
  - SPA routing

### Backend Image
- **Name**: `bayarmaa/eduai-backend:latest`
- **Base**: `node:18-alpine`
- **Port**: 5000
- **Features**:
  - Multi-stage build
  - Production dependencies
  - Non-root user
  - Health checks
  - Security hardening

### AI Service Image
- **Name**: `bayarmaa/eduai-ai-service:latest`
- **Base**: `python:3.11-slim`
- **Port**: 8000
- **Features**:
  - Minimal Python image
  - Non-root user
  - Health checks
  - Security hardening

## 🔧 Build Commands

### Build Individual Images

```bash
# Build only frontend
./build-docker-images.sh frontend

# Build only backend
./build-docker-images.sh backend

# Build only AI service
./build-docker-images.sh ai
```

### Push to Docker Hub

```bash
# Push all images (requires Docker login)
./build-docker-images.sh push

# Build and push everything
./build-docker-images.sh all
```

### Create Dockerfiles

```bash
# Create Dockerfiles if they don't exist
./build-docker-images.sh create
```

## 📁 Project Structure

```
ai-smart-learning-platform/
├── frontend/
│   ├── Dockerfile          # Frontend container configuration
│   ├── nginx.conf          # Nginx configuration
│   └── src/               # React source code
├── backend/
│   ├── Dockerfile          # Backend container configuration
│   ├── package.json        # Node.js dependencies
│   └── src/               # Node.js source code
├── ai-service/
│   ├── Dockerfile          # AI service container configuration
│   ├── requirements.txt    # Python dependencies
│   └── src/               # Python source code
└── build-docker-images.sh   # Build script
```

## 🐳 Dockerfile Details

### Frontend Dockerfile

```dockerfile
# Build stage
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build

# Production stage
FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

### Backend Dockerfile

```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001
RUN chown -R nodejs:nodejs /app
USER nodejs
EXPOSE 5000
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node healthcheck.js
CMD ["npm", "start"]
```

### AI Service Dockerfile

```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
RUN useradd --create-home --shell /bin/bash app
RUN chown -R app:app /app
USER app
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8000/health')"
CMD ["python", "app.py"]
```

## 🔒 Security Features

### Non-Root Containers
- All containers run as non-root users
- Proper file permissions
- Limited capabilities

### Health Checks
- Liveness and readiness probes
- Application-specific health endpoints
- Automatic restart on failure

### Image Optimization
- Multi-stage builds for smaller images
- Minimal base images
- Production-only dependencies
- Cached layers for faster builds

## 🚢 Deployment Integration

### Kubernetes Integration

The deployment script automatically uses these images:

```yaml
# Frontend
image: bayarmaa/eduai-frontend:latest

# Backend
image: bayarmaa/eduai-backend:latest

# AI Service
image: bayarmaa/eduai-ai-service:latest
```

### Environment Configuration

Images are configured to work with the Kubernetes deployment:

- **Frontend**: Static files served by Nginx
- **Backend**: Node.js API with environment variables
- **AI Service**: Python API with OpenAI integration

## 🔄 CI/CD Pipeline

### GitHub Actions Example

```yaml
name: Build and Push Docker Images

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v2
      
    - name: Login to Docker Hub
      uses: docker/login-action@v2
      with:
        username: ${{ secrets.DOCKER_USERNAME }}
        password: ${{ secrets.DOCKER_PASSWORD }}
        
    - name: Build and push frontend
      uses: docker/build-push-action@v4
      with:
        context: ./frontend
        push: true
        tags: bayarmaa/eduai-frontend:latest
        
    - name: Build and push backend
      uses: docker/build-push-action@v4
      with:
        context: ./backend
        push: true
        tags: bayarmaa/eduai-backend:latest
        
    - name: Build and push AI service
      uses: docker/build-push-action@v4
      with:
        context: ./ai-service
        push: true
        tags: bayarmaa/eduai-ai-service:latest
```

## 📊 Image Sizes

| Image | Estimated Size | Optimizations |
|-------|----------------|---------------|
| Frontend | ~50MB | Multi-stage build |
| Backend | ~200MB | Alpine base, prod deps |
| AI Service | ~150MB | Slim Python base |

## 🔧 Customization

### Environment Variables

Images support these environment variables:

**Backend:**
- `NODE_ENV`: production/development
- `PORT`: 5000
- `DB_HOST`: postgres-service
- `REDIS_URL`: redis://redis-service:6379

**AI Service:**
- `OPENAI_API_KEY`: OpenAI API key
- `AI_PROVIDER`: openai/anthropic
- `MAX_TOKENS`: 2000

### Configuration Files

**Frontend nginx.conf:**
- Gzip compression
- Security headers
- SPA routing
- Static file caching

## 🚀 Deployment Commands

### Local Testing

```bash
# Build and run locally
docker build -t bayarmaa/eduai-frontend:latest ./frontend
docker run -p 8080:80 bayarmaa/eduai-frontend:latest

docker build -t bayarmaa/eduai-backend:latest ./backend
docker run -p 5000:5000 bayarmaa/eduai-backend:latest

docker build -t bayarmaa/eduai-ai-service:latest ./ai-service
docker run -p 8000:8000 bayarmaa/eduai-ai-service:latest
```

### Production Deployment

```bash
# Build and push to Docker Hub
./build-docker-images.sh all

# Deploy to Kubernetes
./deploy.sh
```

## 🐛 Troubleshooting

### Build Issues

```bash
# Check Docker daemon
docker info

# Clean build cache
docker builder prune -f

# Check disk space
df -h
```

### Push Issues

```bash
# Check Docker Hub login
docker login

# Verify image exists
docker images | grep bayarmaa
```

### Runtime Issues

```bash
# Check container logs
docker logs <container-name>

# Debug container
docker run -it --entrypoint /bin/sh bayarmaa/eduai-backend:latest
```

## 📞 Support

For Docker image issues:

1. Check the troubleshooting section
2. Review Dockerfile configurations
3. Verify build logs
4. Check Docker Hub repository

---

**🎉 Your Docker images are now ready for deployment!**

Build and push your images, then run `./deploy.sh` to deploy the complete platform.
