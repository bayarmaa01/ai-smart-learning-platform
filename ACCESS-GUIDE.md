# Port Forwarding and Domain Access Guide

## Quick Start

### 1. Start Port Forwarding (Local Access)
```bash
# On Windows (PowerShell)
./port-forward.sh start

# On Linux/Mac
bash port-forward.sh start
```

**Local URLs after port forwarding:**
- Frontend: http://localhost:3000
- Backend:  http://localhost:5000
- API:      http://localhost:5000/api/v1

### 2. Setup Domain Access (Public Access)
```bash
# Setup Cloudflare tunnel (one-time)
./domain-access.sh setup

# Start tunnel
./domain-access.sh start
```

**Public URLs after domain setup:**
- Frontend: https://ailearn.duckdns.org
- API:      https://ailearn.duckdns.org/api/v1

## Script Commands

### port-forward.sh
```bash
./port-forward.sh start    # Start all port forwards
./port-forward.sh stop     # Stop all port forwards
./port-forward.sh status   # Check status
./port-forward.sh restart  # Restart port forwards
```

### domain-access.sh
```bash
./domain-access.sh setup   # Initial Cloudflare setup
./domain-access.sh start   # Start tunnel
./domain-access.sh stop    # Stop tunnel
./domain-access.sh test    # Test domain connectivity
./domain-access.sh status  # Show status
./domain-access.sh urls    # Show all access URLs
```

## Prerequisites

1. **Docker Desktop** must be running
2. **Minikube cluster** must be running:
   ```bash
   minikube start --driver=docker
   eval $(minikube docker-env)
   ```
3. **Services deployed**:
   ```bash
   ./devops-smart.sh --full --force-build
   ```

## Troubleshooting

### Port Forwarding Issues
- Check if minikube is running: `minikube status`
- Check if services exist: `kubectl get pods -n eduai`
- View logs: `tail -f logs/*-forward.log`

### Domain Access Issues
- Install cloudflared: https://github.com/cloudflare/cloudflared/releases
- Check tunnel status: `./domain-access.sh status`
- Test connectivity: `./domain-access.sh test`
- View tunnel logs: `tail -f ~/.cloudflared/tunnel.log`

### Common Issues
1. **"Port already in use"**: Stop existing forwards first
2. **"Cannot connect to cluster"**: Start minikube first
3. **"Domain not accessible"**: Check Cloudflare tunnel status

## Access Summary

| Service | Local URL | Public URL |
|---------|-----------|------------|
| Frontend | http://localhost:3000 | https://ailearn.duckdns.org |
| Backend API | http://localhost:5000 | https://ailearn.duckdns.org/api/v1 |
| Health Check | http://localhost:5000/health | https://ailearn.duckdns.org/api/v1/health |

## Development Workflow

1. Start Docker Desktop
2. Start minikube: `minikube start --driver=docker`
3. Deploy services: `./devops-smart.sh --full --force-build`
4. Start port forwarding: `./port-forward.sh start`
5. (Optional) Setup domain: `./domain-access.sh setup && ./domain-access.sh start`
6. Access your application!

## Notes

- Port forwarding is for **local development**
- Domain access is for **public access** via Cloudflare tunnel
- Both can work simultaneously
- Scripts automatically handle cleanup and process management
