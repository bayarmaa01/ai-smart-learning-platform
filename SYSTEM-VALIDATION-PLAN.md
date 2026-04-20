# System Validation Plan

## Expected Container State
```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```
Should show:
- eduai-postgres: healthy (5433:5432)
- eduai-redis: healthy (6379:6379)
- eduai-ollama: healthy (11435:11434)
- eduai-backend: healthy (4000:5000)
- eduai-ai-service: healthy (5001:8000)
- eduai-frontend: healthy (3000:80)
- eduai-nginx: healthy (80:80, 443:443)
- eduai-prometheus: up (9090:9090)
- eduai-grafana: up (3001:3000)

## Validation Commands

### 1. Database Connectivity
```bash
# Test PostgreSQL
docker exec eduai-postgres pg_isready -U postgres -d eduai

# Test Redis
docker exec eduai-redis redis-cli ping

# Test Ollama
curl -f http://localhost:11435/api/tags || echo "Ollama not ready"
```

### 2. Backend Service
```bash
# Direct backend health check
curl -f http://localhost:4000/api/v1/health

# Test backend database connection
curl -f http://localhost:4000/api/v1/health | jq '.database'

# Test backend Redis connection
curl -f http://localhost:4000/api/v1/health | jq '.redis'
```

### 3. AI Service
```bash
# Direct AI service health check
curl -f http://localhost:5001/health

# Test AI service functionality
curl -f http://localhost:5001/health | jq '.status'
```

### 4. Frontend Service
```bash
# Frontend health check
curl -I http://localhost:3000/

# Test React SPA routing
curl -I http://localhost:3000/login
curl -I http://localhost:3000/dashboard
```

### 5. Nginx Reverse Proxy
```bash
# Nginx health check
curl http://localhost/health

# Test API proxy
curl -f http://localhost/api/v1/health

# Test AI service proxy
curl -f http://localhost/ai/health

# Test WebSocket proxy
curl -I http://localhost/socket.io/

# Test rate limiting
for i in {1..25}; do curl -s http://localhost/api/v1/health | head -1; done
```

### 6. Service-to-Service Communication
```bash
# Backend to Redis
docker exec eduai-backend wget -qO- http://eduai-redis:6379 || echo "Redis unreachable"

# Backend to PostgreSQL
docker exec eduai-backend wget -qO- http://eduai-postgres:5432 || echo "Postgres unreachable"

# Nginx to Backend
docker exec eduai-nginx wget -qO- http://eduai-backend:5000/api/v1/health

# Nginx to AI Service
docker exec eduai-nginx wget -qO- http://eduai-ai-service:8000/health
```

### 7. Full Integration Tests
```bash
# Test login flow through nginx proxy
curl -X POST http://localhost/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com", "password": "testpass"}'

# Test AI service through nginx proxy
curl -f http://localhost/ai/health

# Test frontend with API calls
curl -s http://localhost:3000/ | grep -q "html" && echo "Frontend OK"
```

## Failure Scenarios Testing

### 1. AI Service Failure
```bash
# Stop AI service
docker stop eduai-ai-service

# Test graceful degradation
curl -f http://localhost/ai/health
# Should return 503 with JSON error message

# Verify other services still work
curl -f http://localhost/api/v1/health
curl -I http://localhost:3000/
```

### 2. Backend Failure
```bash
# Stop backend
docker stop eduai-backend

# Test nginx response
curl -f http://localhost/api/v1/health
# Should return 502 Bad Gateway

# Restart backend
docker start eduai-backend
```

### 3. Database Failure
```bash
# Stop PostgreSQL
docker stop eduai-postgres

# Test backend health
curl -f http://localhost/api/v1/health
# Should show database connection error

# Restart PostgreSQL
docker start eduai-postgres
```

## Performance Tests

### 1. Load Testing
```bash
# Concurrent API requests
for i in {1..10}; do curl -s http://localhost/api/v1/health & done
wait

# Rate limiting test
for i in {1..15}; do curl -s http://localhost/api/v1/auth/login \
  -X POST -H "Content-Type: application/json" -d '{}' & done
wait
```

### 2. Memory/CPU Usage
```bash
# Check container resource usage
docker stats --no-stream

# Check nginx status
curl http://localhost/nginx_status
```

## Security Tests

### 1. CORS Headers
```bash
# Test CORS preflight
curl -I -X OPTIONS http://localhost/api/v1/auth/login \
  -H "Origin: http://localhost:3000" \
  -H "Access-Control-Request-Method: POST"
```

### 2. Security Headers
```bash
# Check security headers
curl -I http://localhost/ | grep -E "(X-Frame-Options|X-Content-Type-Options)"
```

## Success Criteria

1. All containers start and stay healthy
2. Frontend loads at http://localhost:3000
3. API calls work through nginx proxy at http://localhost/api/*
4. AI service works through nginx proxy at http://localhost/ai/*
5. Login flow works end-to-end
6. System gracefully handles AI service failures
7. Rate limiting works correctly
8. No CORS errors in browser
9. All inter-service communication works
10. System recovers from service restarts

## Troubleshooting Commands

```bash
# Check container logs
docker logs eduai-nginx
docker logs eduai-backend
docker logs eduai-frontend

# Check network connectivity
docker network ls
docker network inspect ai-smart-learning-platform_eduai-network

# Check service dependencies
docker compose ps
docker compose logs --tail=50

# Force recreation
docker compose down
docker compose up --build -d
```
