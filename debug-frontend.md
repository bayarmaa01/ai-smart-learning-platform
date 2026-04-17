# Frontend Debugging Commands

## Root Cause Analysis
The connection reset issue was caused by:
1. **Incomplete nginx.conf** - Only included conf.d files but no actual server block
2. **Dockerfile override** - Created basic nginx.conf that didn't include server configuration
3. **Missing SPA routing** - No proper fallback to index.html for React/Vite SPA

## Fixed Configuration
- ✅ **Complete nginx.conf** with full server block, security headers, gzip, SPA routing
- ✅ **Dockerfile fix** - Copies complete nginx.conf instead of creating minimal one
- ✅ **Production-ready** - Proper MIME types, caching, and security headers

## Verification Commands

### 1. Rebuild Frontend
```bash
docker compose down frontend
docker compose build --no-cache frontend
docker compose up -d frontend
```

### 2. Test Frontend Access
```bash
# Test from host
curl -I http://localhost:3200

# Test from container (should work)
docker exec eduai-frontend curl -I http://localhost:3000

# Test with different host
curl -I http://127.0.0.1:3200
```

### 3. Verify Configuration
```bash
# Check nginx config inside container
docker exec eduai-frontend cat /etc/nginx/nginx.conf

# Check if files are served correctly
docker exec eduai-frontend ls -la /usr/share/nginx/html

# Check nginx error logs
docker exec eduai-frontend cat /var/log/nginx/error.log
```

### 4. Browser Testing
Open in browser:
- http://localhost:3200
- http://127.0.0.1:3200

## Expected Results
- ✅ **Frontend**: HTTP/1.1 200 OK
- ✅ **SPA Routing**: All routes work correctly
- ✅ **Static Assets**: CSS, JS, images served properly
- ✅ **No Connection Reset**: Stable connection

## Troubleshooting
If issues persist:
1. Check Windows Firewall for port 3200
2. Restart Docker Desktop completely
3. Try different browser (Chrome, Firefox, Edge)
4. Check for other services using port 3200
