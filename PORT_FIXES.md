# Port Configuration Summary

## 🔧 Port Changes Made

Due to local port conflicts, the following external ports have been changed:

### Original → New Ports

| Service | Original Port | New Port | Internal Port |
|---------|---------------|----------|----------------|
| MinIO API | 9000 | 9002 | 9000 |
| MinIO Console | 9001 | 9003 | 9001 |
| PostgreSQL | 5432 | 5433 | 5432 |
| AI Service | 8000 | 8001 | 8000 |
| Backend | 5000 | 5001 | 5000 |

### Unchanged Ports

| Service | Port | Notes |
|---------|------|-------|
| Frontend | 3000 | No conflict |
| Redis | 6379 | No conflict |
| Grafana | 3001 | No conflict |
| Prometheus | 9090 | No conflict |
| Elasticsearch | 9200 | No conflict |

## 🌐 Updated Access URLs

### Platform Services
- 📱 **Frontend**: http://localhost:3000
- 🔧 **Backend API**: http://localhost:5001
- 🤖 **AI Service**: http://localhost:8001

### Monitoring & Tools
- 📈 **Grafana**: http://localhost:3001
- 🔍 **Prometheus**: http://localhost:9090
- 💾 **MinIO Console**: http://localhost:9003

### Databases (External Access)
- 🐘 **PostgreSQL**: localhost:5433
- 🔴 **Redis**: localhost:6379
- 🔎 **Elasticsearch**: http://localhost:9200
- 💾 **MinIO API**: http://localhost:9002

## 📝 Important Notes

1. **Internal Container Communication**: Unchanged
   - Containers still communicate using standard ports internally
   - `postgres:5432`, `ai-service:8000`, `minio:9000` etc.

2. **External Host Access**: Updated
   - Only external access ports changed to avoid conflicts
   - Database connections in code work unchanged

3. **Environment Variables**: Updated where needed
   - Frontend proxy configuration updated
   - Environment files updated for development

## 🚀 Quick Start

```bash
# Start all services with port fixes
./final-fix.sh

# Or manually
docker compose down
docker compose up -d
```

## 📋 Verification Commands

```bash
# Check all services
docker compose ps

# Check port usage
./check-ports.sh

# View logs
docker compose logs -f
```

---

*Last updated: March 13, 2026*
