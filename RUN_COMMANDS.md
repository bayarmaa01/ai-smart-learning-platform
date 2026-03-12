# EduAI Platform - Run Commands

## 🚀 Quick Start

### Prerequisites
- Docker & Docker Compose
- Node.js 20+
- Python 3.11+
- PostgreSQL 15+ (optional, Docker recommended)
- Redis 7+ (optional, Docker recommended)

---

## 📋 Development Commands

### 1. Local Development (Recommended)

```bash
# Clone and setup
git clone https://github.com/your-org/ai-smart-learning-platform.git
cd ai-smart-learning-platform

# Copy environment file
cp .env.example .env

# Start all services with Docker
docker compose up --build

# Access services:
# Frontend: http://localhost:3000
# Backend API: http://localhost:5000
# AI Service: http://localhost:8000
# Grafana: http://localhost:3001
# Kibana: http://localhost:5601
# MinIO Console: http://localhost:9001
```

### 2. Individual Service Development

```bash
# Terminal 1: Start infrastructure
docker compose up postgres redis minio elasticsearch

# Terminal 2: Setup backend
cd backend
cp ../.env.example .env
npm install
npm run setup  # Initialize database and seed data
npm run dev     # Start backend on port 5000

# Terminal 3: Setup AI service
cd ai-service
cp ../.env.example .env
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Terminal 4: Setup frontend
cd frontend
cp ../.env.example .env.example
npm install
npm run dev  # Start frontend on port 3000
```

---

## 🗄️ Database Commands

### Backend Database Management

```bash
cd backend

# Initialize database (creates schema and seeds data)
npm run db:init

# Reset database (drops and recreates everything)
npm run db:reset

# Check database status
npm run db:status

# Run migrations
npm run migrate

# Seed data only
npm run seed

# Complete setup (init + seed)
npm run setup
```

### Manual Database Operations

```bash
# Connect to PostgreSQL
docker compose exec postgres psql -U postgres -d eduai_db

# View tables
\dt

# View users
SELECT * FROM users LIMIT 5;

# View courses
SELECT * FROM courses LIMIT 5;
```

---

## 🐳 Docker Commands

### Full Stack

```bash
# Build and start all services
docker compose up --build

# Start in detached mode
docker compose up -d --build

# Stop all services
docker compose down

# Stop and remove volumes (complete reset)
docker compose down -v

# View logs
docker compose logs -f [service_name]

# View logs for all services
docker compose logs -f

# Restart specific service
docker compose restart [service_name]

# Execute command in container
docker compose exec [service_name] [command]
```

### Individual Services

```bash
# Start only database services
docker compose up postgres redis

# Start only monitoring
docker compose up prometheus grafana

# Start only AI service
docker compose up ai-service

# Build specific service
docker compose build [service_name]

# Pull latest images
docker compose pull
```

---

## 🔧 Service-Specific Commands

### Backend (Node.js)

```bash
cd backend

# Development with hot reload
npm run dev

# Production start
npm start

# Run tests
npm test

# Lint code
npm run lint

# Database operations
npm run db:init
npm run migrate
npm run seed
```

### AI Service (Python)

```bash
cd ai-service

# Development with auto-reload
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Production start
uvicorn main:app --host 0.0.0.0 --port 8000 --workers 4

# Run tests
python -m pytest

# Install dependencies
pip install -r requirements.txt

# Check Python environment
python --version
pip list
```

### Frontend (React)

```bash
cd frontend

# Development server
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview

# Run tests
npm test

# Lint code
npm run lint

# Type check
npm run type-check
```

---

## 📊 Monitoring & Debugging

### Logs

```bash
# View all service logs
docker compose logs -f

# View specific service logs
docker compose logs -f backend
docker compose logs -f ai-service
docker compose logs -f frontend

# View last 100 lines
docker compose logs --tail=100 -f backend
```

### Health Checks

```bash
# Check service health
curl http://localhost:5000/health  # Backend
curl http://localhost:8000/health  # AI Service
curl http://localhost:3000/health  # Frontend

# Check database connection
docker compose exec postgres pg_isready -U postgres

# Check Redis connection
docker compose exec redis redis-cli ping
```

### Metrics

```bash
# Prometheus metrics
curl http://localhost:5000/metrics  # Backend metrics
curl http://localhost:8000/metrics  # AI Service metrics

# Grafana dashboards
# Visit: http://localhost:3001
# Username: admin, Password: admin
```

---

## 🛠️ Troubleshooting Commands

### Common Issues

```bash
# Reset everything
docker compose down -v --remove-orphans
docker system prune -f
docker compose up --build

# Fix permission issues
docker compose exec backend chown -R nodejs:nodejs /app
docker compose exec ai-service chown -R appuser:appuser /app

# Clear Docker cache
docker builder prune -f

# Rebuild specific service
docker compose up --build --force-recreate [service_name]
```

### Database Issues

```bash
# Reset database
docker compose exec postgres psql -U postgres -d eduai_db -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
docker compose restart postgres
npm run db:init

# Check database connections
docker compose exec backend npm run db:status

# Manual database setup
docker compose exec postgres psql -U postgres -d eduai_db -f /docker-entrypoint-initdb.d/01-schema.sql
```

### Port Conflicts

```bash
# Check what's using ports
netstat -tulpn | grep :3000
netstat -tulpn | grep :5000
netstat -tulpn | grep :8000

# Kill processes on ports
sudo lsof -ti:3000 | xargs kill -9
sudo lsof -ti:5000 | xargs kill -9
sudo lsof -ti:8000 | xargs kill -9
```

---

## 🌐 API Testing

### Backend API

```bash
# Health check
curl http://localhost:5000/health

# User registration
curl -X POST http://localhost:5000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Password123!","firstName":"Test","lastName":"User"}'

# User login
curl -X POST http://localhost:5000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Password123!"}'

# Get courses
curl http://localhost:5000/api/v1/courses
```

### AI Service

```bash
# Health check
curl http://localhost:8000/health

# Chat with AI
curl -X POST http://localhost:8000/chat \
  -H "Content-Type: application/json" \
  -d '{"message":"What is Python programming?","session_id":"test-session"}'

# Get recommendations
curl -X POST http://localhost:8000/recommendations \
  -H "Content-Type: application/json" \
  -d '{"user_id":"test-user","enrolled_courses":[],"language_preference":"en"}'
```

---

## 🔒 Security Commands

### SSL/TLS Setup

```bash
# Generate self-signed certificates
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout nginx/ssl/private.key -out nginx/ssl/certificate.crt

# Test HTTPS
curl -k https://localhost/health
```

### Environment Security

```bash
# Check for exposed secrets
grep -r "password\|secret\|key" . --exclude-dir=node_modules --exclude-dir=.git

# Validate environment variables
docker compose config
```

---

## 📈 Performance Commands

### Load Testing

```bash
# Install Apache Bench
sudo apt-get install apache2-utils

# Load test backend
ab -n 1000 -c 10 http://localhost:5000/health

# Load test AI service
ab -n 100 -c 5 http://localhost:8000/health
```

### Resource Monitoring

```bash
# Docker stats
docker stats

# System resources
htop
iostat -x 1
free -h

# Database performance
docker compose exec postgres psql -U postgres -d eduai_db -c "SELECT * FROM pg_stat_activity;"
```

---

## 🚀 Production Deployment

### Docker Production

```bash
# Set production environment
export NODE_ENV=production
export DEBUG=false

# Build and deploy
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build

# Scale services
docker compose up -d --scale backend=3 --scale ai-service=2
```

### Kubernetes

```bash
# Apply Kubernetes manifests
kubectl apply -f k8s/

# Check deployment status
kubectl get pods
kubectl get services

# View logs
kubectl logs -f deployment/backend
```

### Health Verification

```bash
# Full system health check
curl http://localhost:5000/health && \
curl http://localhost:8000/health && \
curl http://localhost:3000/health && \
echo "All services healthy!"
```

---

## 📚 Useful Commands

### Development Workflow

```bash
# Start fresh development environment
git pull origin main
docker compose down -v
docker compose up --build
npm run setup  # In backend directory
```

### Code Quality

```bash
# Backend linting
cd backend && npm run lint

# Frontend linting
cd frontend && npm run lint

# Run all tests
npm run test  # In each service directory
```

### Data Management

```bash
# Backup database
docker compose exec postgres pg_dump -U postgres eduai_db > backup.sql

# Restore database
docker compose exec -T postgres psql -U postgres eduai_db < backup.sql

# Export data
docker compose exec postgres psql -U postgres -d eduai_db -c "COPY users TO '/tmp/users.csv' WITH CSV HEADER;"
docker compose cp postgres:/tmp/users.csv ./
```

---

## 🆘 Emergency Commands

### Complete Reset

```bash
# Stop and remove everything
docker compose down -v --remove-orphans
docker system prune -af

# Rebuild from scratch
docker compose build --no-cache
docker compose up --force-recreate
```

### Service Recovery

```bash
# Restart specific service
docker compose restart backend

# Recreate service
docker compose up -d --force-recreate backend

# Check service status
docker compose ps
```

---

## 📞 Support

### Getting Help

```bash
# Check service status
docker compose ps

# View service logs
docker compose logs [service_name]

# Access service shell
docker compose exec [service_name] sh

# Check environment
docker compose exec [service_name] env | sort
```

### Debug Mode

```bash
# Enable debug logging
export DEBUG=true
export NODE_ENV=development

# Run with verbose output
docker compose up --build --verbose
```

---

*Save this file for quick reference during development and deployment!*
