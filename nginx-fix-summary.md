# Nginx CORS Fix - Root Cause Analysis

## Problem Identified
1. **Nginx Configuration Structure Error**: `nginx/nginx.conf` contained full nginx config (worker_processes, events, http blocks) but was being copied to `/etc/nginx/conf.d/default.conf` - this is invalid
2. **CORS Issues**: Because nginx was crashing, frontend made direct cross-origin calls to backend, triggering CORS errors
3. **Proxy Misconfiguration**: nginx wasn't properly acting as reverse proxy to eliminate CORS need

## Root Cause
- `worker_processes` directive can only exist in main nginx.conf, not in conf.d/*.conf files
- Frontend Dockerfile was copying wrong nginx configuration structure
- Docker-compose was mounting wrong config file to wrong location

## Solutions Applied

### 1. Correct Nginx Configuration Structure

**nginx/nginx-main.conf** (main config):
```nginx
worker_processes auto;
events { worker_connections 1024; }
http {
    include /etc/nginx/mime.types;
    # ... global settings
    include /etc/nginx/conf.d/*.conf;
}
```

**nginx/default.conf** (server block only):
```nginx
server {
    listen 80;
    # Frontend: location / { ... }
    # Backend: location /api/ { proxy_pass http://eduai-backend:5000; }
    # AI Service: location /ai/ { proxy_pass http://eduai-ai-service:8000; }
}
```

### 2. Fixed Docker Compose Volumes
```yaml
nginx:
  volumes:
    - ./nginx/nginx-main.conf:/etc/nginx/nginx.conf
    - ./nginx/default.conf:/etc/nginx/conf.d/default.conf
```

### 3. Updated Frontend Dockerfile
```dockerfile
COPY ../nginx/default.conf /etc/nginx/conf.d/default.conf
```

### 4. Eliminated CORS Need
- Frontend now calls `/api/*` (same origin)
- nginx proxies to backend services
- No cross-origin requests = no CORS needed

## Service Names Verified
- Backend: `eduai-backend:5000` (internal)
- AI Service: `eduai-ai-service:8000` (internal)
- Frontend: `frontend:80` (internal)
- Nginx: `nginx:80` (external)

## Testing Commands
```bash
# Rebuild and restart
docker compose down
docker compose up --build -d

# Test nginx startup
docker logs eduai-nginx

# Test proxy functionality
curl http://localhost/api/v1/health
```

## Expected Result
- Nginx starts without errors
- Frontend loads at http://localhost:3000
- API calls work via proxy (no CORS errors)
- All services communicate internally
