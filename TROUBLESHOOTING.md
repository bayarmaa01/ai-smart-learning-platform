# EduAI Platform - Troubleshooting Guide

## 🚨 Common Issues & Solutions

### 1. Authentication Issues

**Problem**: Login returns 500 error
**Solution**:
```bash
# Check backend logs
docker-compose logs -f backend

# Restart backend
docker-compose restart backend

# Verify database connection
docker exec eduai-postgres psql -U postgres -d eduai -c "SELECT COUNT(*) FROM users;"
```

**Problem**: User can access dashboard without login
**Solution**:
```bash
# Clear browser localStorage
# Open browser dev tools → Application → Local Storage → Clear all

# Restart frontend
docker-compose restart frontend

# Check AuthContext
# Verify token validation is working
```

### 2. API Connection Issues

**Problem**: API calls return network error
**Solution**:
```bash
# Check nginx configuration
docker exec eduai-nginx nginx -t

# Test API directly
curl http://localhost:80/api/v1/health

# Check service networking
docker network ls
docker network inspect ai-smart-learning-platform_eduai-network
```

**Problem**: CORS errors
**Solution**:
```bash
# Restart nginx to apply CORS config
docker-compose restart nginx

# Check backend CORS settings
docker-compose logs backend | grep -i cors
```

### 3. Database Issues

**Problem**: Database schema errors
**Solution**:
```bash
# Recreate database with new schema
docker-compose down -v
docker volume rm ai-smart-learning-platform_postgres_data
docker-compose up -d postgres

# Wait for initialization
sleep 30
docker-compose logs postgres
```

**Problem**: Connection refused to database
**Solution**:
```bash
# Check if postgres is running
docker ps | grep postgres

# Test database connection
docker exec eduai-postgres pg_isready -U postgres

# Restart database
docker-compose restart postgres
```

### 4. Frontend Issues

**Problem**: Blank screen / vendor.js error
**Solution**:
```bash
# Rebuild frontend
docker-compose build --no-cache frontend
docker-compose up -d frontend

# Check nginx routing
curl -I http://localhost:80/

# Clear browser cache
# Hard refresh: Ctrl+Shift+R (Windows/Linux) or Cmd+Shift+R (Mac)
```

**Problem**: Login and dashboard showing together
**Solution**:
```bash
# Check React Router configuration
# Verify ProtectedRoute is working

# Restart frontend
docker-compose restart frontend

# Check browser console for JavaScript errors
```

### 5. Docker Issues

**Problem**: Services not starting
**Solution**:
```bash
# Check Docker daemon
docker version
docker info

# Clean up Docker
docker system prune -a
docker volume prune

# Rebuild all services
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

**Problem**: Port conflicts
**Solution**:
```bash
# Check what's using ports
netstat -tulpn | grep :80
netstat -tulpn | grep :5432

# Stop conflicting services
sudo systemctl stop nginx  # If nginx is running on host
sudo systemctl stop apache2  # If apache is running on host
```

## 🔧 Debugging Commands

### Check Service Status
```bash
# All services
docker-compose ps

# Specific service logs
docker-compose logs -f backend
docker-compose logs -f frontend
docker-compose logs -f nginx
```

### Test API Endpoints
```bash
# Health check
curl http://localhost:80/api/v1/health

# Test registration
curl -X POST http://localhost:80/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"test123456","firstName":"Test","lastName":"User","role":"student"}'

# Test login
curl -X POST http://localhost:80/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"test123456"}'
```

### Database Operations
```bash
# Connect to database
docker exec -it eduai-postgres psql -U postgres -d eduai

# Check users table
SELECT id, email, role, is_active FROM users LIMIT 5;

# Check database schema
\d users;

# Reset admin user
UPDATE users SET password_hash = '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj6QJw/2Ej7W' WHERE email = 'admin@eduai.com';
```

## 📊 Monitoring

### Prometheus Issues
```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# Check Prometheus config
docker exec eduai-prometheus cat /etc/prometheus/prometheus.yml

# Restart Prometheus
docker-compose restart prometheus
```

### Grafana Issues
```bash
# Check Grafana logs
docker-compose logs grafana

# Access Grafana
# URL: http://localhost:3001
# Username: admin
# Password: admin
```

## 🚀 Quick Recovery

If everything is broken, run this complete reset:

```bash
# Complete system reset
docker-compose down -v
docker system prune -a
docker volume prune

# Rebuild from scratch
./rebuild-system.sh

# Verify everything works
./verify-system.sh
```

## 📱 Browser Testing

1. **Clear Browser Data**: Clear localStorage, cookies, and cache
2. **Hard Refresh**: Ctrl+Shift+R or Cmd+Shift+R
3. **Check Console**: Open DevTools → Console for JavaScript errors
4. **Check Network**: DevTools → Network for failed requests
5. **Test Incognito**: Try in incognito/private mode

## 🆘 Getting Help

If issues persist:

1. **Check logs first**: `docker-compose logs -f [service]`
2. **Run verification**: `./verify-system.sh`
3. **Document the error**: What were you doing? What error appeared?
4. **Check this guide**: Look for similar issues above

## 📝 System Architecture

```
Internet → Nginx (Port 80) → Frontend (Port 80)
                    → Backend (Port 5000)
                    
Backend → PostgreSQL (Port 5432)
        → Redis (Port 6379)
        → Ollama (Port 11434)
```

Understanding this helps debug networking issues!
