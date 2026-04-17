# Debugging Minified React Errors in Production

## Root Cause: Docker Network Isolation

### Why "localhost" Fails in Docker Frontend
- **Frontend Container**: `localhost` resolves to frontend container itself
- **Backend Service**: Runs in separate container named `backend:5000`
- **Network Isolation**: Containers can't reach each other via `localhost`
- **Solution**: Use nginx reverse proxy or Docker service names

## Fixed Configuration

### 1. Nginx Reverse Proxy (/api -> backend)
```nginx
location /api {
    proxy_pass http://backend:5000;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    
    # CORS headers
    proxy_set_header Access-Control-Allow-Origin *;
    proxy_set_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS";
    proxy_set_header Access-Control-Allow-Headers "Origin, X-Requested-With, Content-Type, Accept, Authorization";
}
```

### 2. Frontend Environment Variables
```yaml
environment:
  VITE_API_URL: http://localhost:3200/api/v1  # Use nginx proxy
  VITE_ENV: production
```

### 3. API Service Configuration
```javascript
const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || 'http://localhost:3200/api/v1',
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
  },
});
```

## Debugging Minified React Errors

### 1. Enable Source Maps in Production
```javascript
// vite.config.js
export default {
  build: {
    sourcemap: true,  // Enable source maps for debugging
  }
}
```

### 2. Console Debugging Techniques
```javascript
// Add error boundary to catch errors
class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }

  componentDidCatch(error, errorInfo) {
    console.error('React Error:', error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      return (
        <div>
          <h2>Something went wrong.</h2>
          <details style={{ whiteSpace: 'pre-wrap' }}>
            {this.state.error && this.state.error.toString()}
          </details>
        </div>
      );
    }

    return this.props.children;
  }
}
```

### 3. Network Request Debugging
```javascript
// Add request interceptor for debugging
api.interceptors.request.use(
  (config) => {
    console.log('API Request:', config.method?.toUpperCase(), config.url);
    return config;
  },
  (error) => {
    console.error('Request Error:', error);
    return Promise.reject(error);
  }
);

api.interceptors.response.use(
  (response) => {
    console.log('API Response:', response.status, response.config.url);
    return response;
  },
  (error) => {
    console.error('Response Error:', error.response?.status, error.config?.url);
    return Promise.reject(error);
  }
);
```

### 4. Development Build for Testing
```bash
# Build with source maps and dev mode
docker compose build --build-arg VITE_BUILD_MODE=development frontend
```

## Best Practices for Production Docker Setup

### 1. Use Nginx Reverse Proxy
- **Pros**: Single entry point, CORS handling, SSL termination
- **Cons**: Additional configuration complexity

### 2. Use Docker Service Names
- **Alternative**: `VITE_API_URL: http://backend:5000/api/v1`
- **Pros**: Direct communication, simpler setup
- **Cons**: Requires CORS configuration in backend

### 3. Environment Variable Strategy
```yaml
# Production (nginx proxy)
VITE_API_URL: http://localhost:3200/api/v1

# Alternative (direct service)
VITE_API_URL: http://backend:5000/api/v1
```

## Testing the Fix

### 1. Rebuild and Restart
```bash
docker compose down frontend
docker compose build --no-cache frontend
docker compose up -d frontend
```

### 2. Test API Communication
```bash
# Test nginx proxy
curl http://localhost:3200/api/v1/health

# Test direct backend
curl http://localhost:4200/api/v1/health
```

### 3. Browser Console Check
- Open browser dev tools
- Check Network tab for API requests
- Verify no "Uncaught Error" messages
- Confirm API responses are successful

## Expected Results

After applying these fixes:
- **No more "Uncaught Error"** from vendor-*.js
- **API requests succeed** through nginx proxy
- **React app loads** without crashing
- **Console logs** show successful API calls
- **Source maps** available for debugging
