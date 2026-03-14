# AI Smart Learning Platform - Kubernetes Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying the AI Smart Learning Platform to Kubernetes with complete monitoring, security, and GitOps automation.

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │    Backend       │    │   AI Service    │
│   (React)       │◄──►│   (Node.js)      │◄──►│   (Python)      │
│   Port: 8080    │    │   Port: 5000    │    │   Port: 8000    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
         ┌─────────────────┐    │    ┌─────────────────┐
         │   PostgreSQL    │◄───┼───►│     Redis       │
         │   Port: 5432    │    │    │   Port: 6379    │
         └─────────────────┘    │    └─────────────────┘
                                │
         ┌─────────────────┐    │    ┌─────────────────┐
         │   Ingress       │◄───┼───►   Monitoring    │
         │   (NGINX)       │    │    │ (Prometheus)    │
         └─────────────────┘    │    │ (Grafana)       │
                                │    │ (AlertManager) │
                                │    └─────────────────┘
                                │
         ┌─────────────────┐    │
         │     ArgoCD      │◄───┘
         │   (GitOps)      │
         └─────────────────┘
```

## Prerequisites

### Required Tools
- Docker Desktop
- kubectl
- helm
- kind or minikube (for local development)

### Optional Tools
- ArgoCD CLI
- Terraform (for IaC)
- Ansible (for configuration)

## Quick Start

### 1. Setup Local Cluster

```bash
# Clone the repository
git clone https://github.com/your-org/ai-smart-learning-platform.git
cd ai-smart-learning-platform

# Setup local Kubernetes cluster (Kind recommended)
chmod +x setup-local-cluster.sh
./setup-local-cluster.sh setup
```

### 2. Deploy Platform

```bash
# Deploy complete platform
chmod +x deploy-k8s.sh
./deploy-k8s.sh deploy
```

### 3. Access Services

```bash
# For local cluster, use port-forwarding
kubectl port-forward -n eduai svc/frontend-service 8080:8080
kubectl port-forward -n eduai svc/backend-service 5000:5000
kubectl port-forward -n monitoring svc/grafana 3000:3000
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Access URLs
# Frontend: http://localhost:8080
# Backend API: http://localhost:5000
# Grafana: http://localhost:3000 (admin/admin123)
# Prometheus: http://localhost:9090
```

## Detailed Deployment Steps

### Step 1: Cluster Setup

#### Option A: Kind (Recommended)
```bash
# Setup Kind cluster with 3 nodes
CLUSTER_TYPE=kind ./setup-local-cluster.sh setup
```

#### Option B: Minikube
```bash
# Setup Minikube cluster
CLUSTER_TYPE=minikube ./setup-local-cluster.sh setup
```

### Step 2: Infrastructure Deployment

```bash
# Deploy only infrastructure (PostgreSQL, Redis)
./deploy-k8s.sh infra
```

**What gets deployed:**
- PostgreSQL StatefulSet with persistent storage
- Redis StatefulSet with persistence
- ConfigMaps with environment variables
- Secrets with sensitive data
- Network policies for security

### Step 3: Application Deployment

```bash
# Deploy applications (Backend, AI Service, Frontend)
./deploy-k8s.sh apps
```

**What gets deployed:**
- Backend API with Horizontal Pod Autoscaling
- AI Service with resource optimization
- Frontend with static serving
- Service accounts and RBAC
- Health checks and readiness probes

### Step 4: Networking Setup

```bash
# Configure networking (Ingress, Network Policies)
./deploy-k8s.sh networking
```

**What gets configured:**
- NGINX Ingress Controller
- TLS termination with cert-manager
- Network policies for pod-to-pod communication
- Security headers and rate limiting

### Step 5: Monitoring Stack

```bash
# Deploy monitoring (Prometheus, Grafana, AlertManager)
./deploy-k8s.sh monitoring
```

**What gets deployed:**
- Prometheus for metrics collection
- Grafana for visualization
- AlertManager for alerting
- Custom dashboards and alerts

### Step 6: GitOps Setup

```bash
# Configure ArgoCD for GitOps
./deploy-k8s.sh argocd
```

**What gets configured:**
- ArgoCD application definitions
- Automated sync policies
- Environment-specific deployments

## Configuration

### Environment Variables

Edit `k8s/configmap.yaml` to configure:

```yaml
data:
  NODE_ENV: "production"
  PORT: "5000"
  DB_HOST: "postgres-service"
  REDIS_URL: "redis://redis-service:6379"
  AI_SERVICE_URL: "http://ai-service:8000"
  LOG_LEVEL: "info"
```

### Secrets

Update `k8s/eduai-secrets.yaml` with your actual values:

```bash
# Generate base64 encoded secrets
echo -n "your-db-password" | base64
echo -n "your-jwt-secret" | base64
echo -n "your-openai-api-key" | base64
```

### Ingress Configuration

Update `k8s/ingress.yaml` with your domain:

```yaml
spec:
  tls:
    - hosts:
        - your-domain.com
  rules:
    - host: your-domain.com
```

## Scaling and Autoscaling

### Horizontal Pod Autoscaling

The deployment includes HPA configurations:

```yaml
# Backend HPA
minReplicas: 3
maxReplicas: 20
metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### Manual Scaling

```bash
# Scale backend to 5 replicas
kubectl scale deployment backend --replicas=5 -n eduai

# Scale frontend to 3 replicas
kubectl scale deployment frontend --replicas=3 -n eduai
```

## Monitoring and Observability

### Grafana Dashboards

Access Grafana at `http://localhost:3000`:
- Username: `admin`
- Password: `admin123`

**Available Dashboards:**
- Kubernetes Cluster Overview
- Application Performance Metrics
- Database Performance
- AI Service Metrics

### Prometheus Metrics

Access Prometheus at `http://localhost:9090`:
- Application metrics: `/metrics`
- Custom business metrics
- Infrastructure metrics

### Alerting

AlertManager is configured with:
- Email notifications for critical alerts
- Slack integration (configurable)
- Custom alert rules

## Security

### Network Policies

```yaml
# Default deny all ingress/egress
# Allow specific pod-to-pod communication
# Allow DNS resolution
# Allow external API calls
```

### Pod Security

- Non-root containers
- Read-only filesystems where possible
- Capability dropping
- Resource limits

### Secrets Management

- Kubernetes secrets for sensitive data
- Environment-specific configurations
- RBAC for access control

## GitOps with ArgoCD

### Application Structure

```
helm/eduai/
├── Chart.yaml
├── values.yaml
├── values-staging.yaml
├── values-production.yaml
└── templates/
    ├── backend/
    ├── frontend/
    ├── ai-service/
    └── monitoring/
```

### Sync Policies

- **Production**: Manual approval required
- **Staging**: Automated sync
- **Development**: Automated sync with self-heal

## Troubleshooting

### Common Issues

1. **Pods not starting**
   ```bash
   kubectl describe pod <pod-name> -n eduai
   kubectl logs <pod-name> -n eduai
   ```

2. **Ingress not working**
   ```bash
   kubectl get ingress -n eduai
   kubectl describe ingress eduai-ingress -n eduai
   ```

3. **Database connection issues**
   ```bash
   kubectl exec -it postgres-0 -n eduai -- psql -U postgres -d eduai_db
   ```

4. **High memory usage**
   ```bash
   kubectl top pods -n eduai
   kubectl describe hpa backend-hpa -n eduai
   ```

### Debug Commands

```bash
# Check all resources
kubectl get all -n eduai

# Check pod events
kubectl get events -n eduai --sort-by='.lastTimestamp'

# Port-forward to debug
kubectl port-forward deployment/backend 5000:5000 -n eduai

# Exec into pod
kubectl exec -it deployment/backend -n eduai -- /bin/bash
```

## Production Considerations

### Resource Requirements

| Component | CPU | Memory | Storage |
|-----------|-----|--------|---------|
| Backend   | 500m | 512Mi  | -       |
| Frontend  | 200m | 256Mi  | -       |
| AI Service| 1000m| 2Gi    | -       |
| PostgreSQL| 250m | 512Mi  | 20Gi    |
| Redis     | 100m | 256Mi  | 5Gi     |

### Backup Strategy

- PostgreSQL: Daily automated backups
- Redis: AOF persistence
- ConfigMaps: Git version control
- Secrets: External secret management

### Disaster Recovery

- Multi-zone deployment
- Database replication
- Regular backup testing
- Documentation restoration procedures

## Performance Optimization

### Database Optimization

```sql
-- Create indexes for common queries
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_courses_category ON courses(category);
```

### Caching Strategy

- Redis for session storage
- Application-level caching
- CDN for static assets
- Database query caching

### Resource Optimization

- Right-size containers
- Use resource requests/limits
- Implement HPA
- Monitor and tune regularly

## Maintenance

### Updates and Upgrades

```bash
# Update application
git pull origin main
./deploy-k8s.sh deploy

# Update Kubernetes versions
kind upgrade cluster --name eduai-cluster --image kindest/node:v1.29.0
```

### Regular Tasks

- Monitor resource usage
- Review security policies
- Update dependencies
- Backup configurations
- Test disaster recovery

## Support

For issues and questions:
- Check the troubleshooting section
- Review Kubernetes logs
- Consult the documentation
- Contact the DevOps team

---

**Note**: This deployment guide is for production-ready Kubernetes deployment. For development, consider using Docker Compose for simpler setup.
