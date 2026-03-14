#!/bin/bash

# Build Docker images for AI Smart Learning Platform
# Uses bayarmaa Docker Hub username

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOCKER_USERNAME="bayarmaa"
REGISTRY="$DOCKER_USERNAME"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_banner() {
    echo -e "${BLUE}"
    cat << "EOF"
    ____        __          __   _                 
   / __ \____  / /_  ____ _ / /  (_)___  ____ _ 
  / /_/ / __ \/ __ \/ __ `// /  / / __ \/ __ `/
 / ____/ /_/ / / / /_/ // /__/ / / / /_/ /  
/_/    \____/_/ /_/\__,_//____/_//_/ /_/\__,_/   
                                                   
    Docker Images Build Script
    Docker Hub: $DOCKER_USERNAME
EOF
    echo -e "${NC}"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        log_error "Docker is not running. Please start Docker first."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

build_frontend() {
    log_info "Building Frontend Docker image..."
    
    if [ -d "frontend" ]; then
        log_success "Building frontend image..."
        docker build -t $REGISTRY/eduai-frontend:latest ./frontend
        log_success "Frontend image built: $REGISTRY/eduai-frontend:latest"
    else
        log_error "Frontend directory not found"
    fi
}

build_backend() {
    log_info "Building Backend Docker image..."
    
    if [ -d "backend" ]; then
        log_success "Building backend image..."
        docker build -t $REGISTRY/eduai-backend:latest ./backend
        log_success "Backend image built: $REGISTRY/eduai-backend:latest"
    else
        log_error "Backend directory not found"
    fi
}

build_ai_service() {
    log_info "Building AI Service Docker image..."
    
    if [ -d "ai-service" ]; then
        log_success "Building AI service image..."
        docker build -t $REGISTRY/eduai-ai-service:latest ./ai-service
        log_success "AI Service image built: $REGISTRY/eduai-ai-service:latest"
    else
        log_error "AI Service directory not found"
    fi
}

push_images() {
    log_info "Pushing images to Docker Hub..."
    
    # Login to Docker Hub
    log_info "Please login to Docker Hub:"
    docker login
    
    # Push images
    log_info "Pushing frontend image..."
    docker push $REGISTRY/eduai-frontend:latest
    
    log_info "Pushing backend image..."
    docker push $REGISTRY/eduai-backend:latest
    
    log_info "Pushing AI service image..."
    docker push $REGISTRY/eduai-ai-service:latest
    
    log_success "All images pushed to Docker Hub"
}

show_images() {
    log_info "Built Docker images:"
    docker images | grep $REGISTRY/eduai
}

create_dockerfiles() {
    log_info "Creating Dockerfiles if they don't exist..."
    
    # Frontend Dockerfile
    if [ ! -f "frontend/Dockerfile" ]; then
        log_info "Creating Frontend Dockerfile..."
        mkdir -p frontend
        cat > frontend/Dockerfile << 'EOF'
# Build stage
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./
RUN npm ci --only=production

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Production stage
FROM nginx:alpine

# Copy built app
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Expose port
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
EOF
    fi
    
    # Backend Dockerfile
    if [ ! -f "backend/Dockerfile" ]; then
        log_info "Creating Backend Dockerfile..."
        mkdir -p backend
        cat > backend/Dockerfile << 'EOF'
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy source code
COPY . .

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Change ownership
RUN chown -R nodejs:nodejs /app

USER nodejs

# Expose port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node healthcheck.js

# Start the application
CMD ["npm", "start"]
EOF
    fi
    
    # AI Service Dockerfile
    if [ ! -f "ai-service/Dockerfile" ]; then
        log_info "Creating AI Service Dockerfile..."
        mkdir -p ai-service
        cat > ai-service/Dockerfile << 'EOF'
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY . .

# Create non-root user
RUN useradd --create-home --shell /bin/bash app

# Change ownership
RUN chown -R app:app /app

USER app

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8000/health')"

# Start the application
CMD ["python", "app.py"]
EOF
    fi
    
    # Frontend nginx.conf
    if [ ! -f "frontend/nginx.conf" ]; then
        log_info "Creating nginx configuration..."
        cat > frontend/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    server {
        listen 80;
        server_name localhost;
        root /usr/share/nginx/html;
        index index.html;

        # Gzip compression
        gzip on;
        gzip_vary on;
        gzip_min_length 1024;
        gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss text/javascript;

        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;

        # Static file caching
        location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }

        # SPA routing
        location / {
            try_files $uri $uri/ /index.html;
        }
    }
}
EOF
    fi
    
    log_success "Dockerfiles and configurations created"
}

show_help() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  build      - Build all Docker images"
    echo "  frontend   - Build only frontend image"
    echo "  backend    - Build only backend image"
    echo "  ai         - Build only AI service image"
    echo "  push       - Push all images to Docker Hub"
    echo "  all        - Build and push all images"
    echo "  create     - Create Dockerfiles if missing"
    echo "  help       - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 all            # Build and push everything"
    echo "  $0 build          # Build all images"
    echo "  $0 push           # Push all images"
    echo "  $0 create         # Create Dockerfiles"
}

# Main script logic
main() {
    show_banner
    
    case "${1:-build}" in
        "build")
            check_prerequisites
            create_dockerfiles
            build_frontend
            build_backend
            build_ai_service
            show_images
            log_success "🎉 All Docker images built successfully!"
            ;;
        "frontend")
            check_prerequisites
            create_dockerfiles
            build_frontend
            show_images
            ;;
        "backend")
            check_prerequisites
            create_dockerfiles
            build_backend
            show_images
            ;;
        "ai")
            check_prerequisites
            create_dockerfiles
            build_ai_service
            show_images
            ;;
        "push")
            check_prerequisites
            push_images
            ;;
        "all")
            check_prerequisites
            create_dockerfiles
            build_frontend
            build_backend
            build_ai_service
            push_images
            show_images
            log_success "🎉 All Docker images built and pushed successfully!"
            ;;
        "create")
            create_dockerfiles
            log_success "🎉 Dockerfiles created successfully!"
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"
