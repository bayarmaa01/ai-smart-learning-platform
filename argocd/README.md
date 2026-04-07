# ArgoCD Setup for EduAI Platform

## Overview
This directory contains ArgoCD configuration for the EduAI Smart Learning Platform.

## Services

### ArgoCD Components
- **argocd-server**: Main ArgoCD API and UI server
- **argocd-repo-server**: Git repository server for ArgoCD
- **argocd-redis**: Redis cache for ArgoCD
- **argocd-application-controller**: Application controller for GitOps

### Access Points
- **ArgoCD UI**: http://localhost:8080
- **ArgoCD API**: http://localhost:3012
- **Repo Server**: http://localhost:8081

### Configuration
- **Namespace**: eduai
- **Insecure Mode**: Enabled (for development)
- **Repository**: https://github.com/bayarmaa01/ai-smart-learning-platform.git
- **Target Path**: k8s/

## Usage

### Start ArgoCD Stack
```bash
# Start all ArgoCD services
docker-compose up argocd-server argocd-repo-server argocd-redis argocd-application-controller

# Or start with the full stack
docker-compose up
```

### Access ArgoCD
1. Open http://localhost:8080 in your browser
2. Default credentials: admin/admin123
3. Configure your Git repository
4. Deploy applications

### Application Configuration
The main application is configured in `config/eduai-app.yaml`:
- Monitors the main repository
- Deploys to `eduai` namespace
- Automated sync enabled
- Self-healing enabled

### Volumes
- `argocd_data`: Persistent storage for configurations
- `argocd/ssh`: SSH keys for repository access
- `argocd/config`: Application configurations

## Development Notes
- Insecure mode is enabled for development
- Redis is used for caching and session management
- Health checks are configured for all services
- All services are connected to the `eduai-network`

## Production Considerations
For production deployment:
1. Disable insecure mode
2. Configure proper SSL certificates
3. Set up proper authentication
4. Configure RBAC permissions
5. Use external Redis instance
6. Set up proper backup strategies
