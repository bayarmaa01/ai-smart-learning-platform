# AI Smart Learning Platform - Automatic Deployment Guide

## Overview

This guide provides a complete automatic deployment solution for the AI Smart Learning Platform using Kubernetes with DuckDNS domain (ailearn.duckdns.org).

## 🚀 Quick Start

### One-Command Deployment

```bash
# Clone and deploy
git clone https://github.com/bayarmaa01/ai-smart-learning-platform.git
cd ai-smart-learning-platform
chmod +x deploy.sh
./deploy.sh
```

That's it! The entire platform will be deployed automatically.

## 📋 What Gets Deployed Automatically

### 🏗️ Infrastructure Stack
- ✅ **Minikube Cluster** - Local Kubernetes with 4 CPUs, 8GB RAM
- ✅ **PostgreSQL** - Database with persistent storage
- ✅ **Redis** - Cache with persistence
- ✅ **NGINX Ingress** - Load balancer with TLS
- ✅ **cert-manager** - Let's Encrypt SSL certificates

### 🎯 Application Services
- ✅ **Frontend** - React application (Port 8080)
- ✅ **Backend API** - Node.js API (Port 5000)
- ✅ **AI Service** - Python LLM service (Port 8000)

### 📊 Monitoring & Observability
- ✅ **Prometheus** - Metrics collection
- ✅ **Grafana** - Visualization dashboards
- ✅ **AlertManager** - Alert notifications
- ✅ **ArgoCD** - GitOps automation

### 🔒 Security Features
- ✅ **TLS/SSL** - HTTPS with Let's Encrypt
- ✅ **Network Policies** - Zero-trust security
- ✅ **Secrets Management** - Encrypted credentials
- ✅ **Rate Limiting** - DDoS protection
- ✅ **Security Headers** - XSS/CSRF protection

## 🌐 Access URLs

After deployment, your platform will be available at:

### 📱 Main Application
- **Frontend**: https://ailearn.duckdns.org
- **Backend API**: https://ailearn.duckdns.org/api
- **AI Service**: https://ailearn.duckdns.org/ai

### 📊 Monitoring
- **Grafana**: https://grafana.ailearn.duckdns.org (admin/admin123)
- **Prometheus**: http://localhost:9090

### 🔧 Local Access (if needed)
```bash
# Port forwarding
kubectl port-forward -n eduai svc/frontend-service 8080:80
kubectl port-forward -n eduai svc/backend-service 5000:5000
kubectl port-forward -n eduai svc/ai-service 8000:8000
kubectl port-forward -n monitoring svc/grafana 3000:3000
kubectl port-forward -n monitoring svc/prometheus 9090:9090
```

## 📜 Deployment Script Features

### 🔄 Automated Steps
1. **Prerequisites Check** - Validates kubectl, helm, minikube
2. **Cluster Setup** - Starts Minikube with optimal configuration
3. **Namespace Creation** - Creates eduai and monitoring namespaces
4. **Secrets & ConfigMaps** - Applies configuration and credentials
5. **Infrastructure** - Deploys PostgreSQL and Redis
6. **Applications** - Deploys backend, AI service, frontend
7. **Ingress Setup** - Configures NGINX with TLS
8. **Monitoring** - Installs Prometheus and Grafana
9. **GitOps** - Deploys ArgoCD for automation
10. **Verification** - Checks all deployments are ready

### 🛠️ Script Commands

```bash
# Complete deployment (default)
./deploy.sh

# Verify deployment status
./deploy.sh verify

# Clean up everything
./deploy.sh cleanup

# Show help
./deploy.sh help
```

## 🔧 Configuration

### 📝 Environment Variables

Edit the generated ConfigMaps to customize:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: eduai-config
  namespace: eduai
data:
  NODE_ENV: "production"
  PORT: "5000"
  DB_HOST: "postgres-service"
  REDIS_URL: "redis://redis-service:6379"
  AI_SERVICE_URL: "http://ai-service:8000"
  ALLOWED_ORIGINS: "https://ailearn.duckdns.org"
```

### 🔐 Secrets Management

Update secrets with your actual values:

```bash
# Generate base64 encoded secrets
echo -n "your-db-password" | base64
echo -n "your-jwt-secret" | base64
echo -n "your-openai-api-key" | base64

# Update in k8s/eduai-secrets.yaml
```

### 🌍 Domain Configuration

The script is pre-configured for:
- **Domain**: ailearn.duckdns.org
- **Email**: admin@ailearn.duckdns.org (for Let's Encrypt)

To change domain, update these files:
- `k8s/ingress.yml` - Change host field
- `deploy.sh` - Update DOMAIN variable
- `k8s/cert-manager.yaml` - Update email

## 📊 Monitoring Setup

### Grafana Dashboards

Access Grafana at https://grafana.ailearn.duckdns.org:
- **Username**: admin
- **Password**: admin123

**Pre-configured Dashboards:**
- Kubernetes Cluster Overview
- Application Performance Metrics
- Database Performance
- AI Service Metrics

### Prometheus Metrics

Access Prometheus at http://localhost:9090:
- Application metrics: `/metrics`
- Custom business metrics
- Infrastructure metrics

### Alerting

AlertManager is configured with:
- Email notifications for critical alerts
- Custom alert rules for platform health

## 🔒 Security Configuration

### Network Security

```yaml
# Network policies implemented
- Default deny all ingress/egress
- Allow specific pod-to-pod communication
- Allow DNS resolution
- Allow external API calls
```

### TLS/SSL Setup

- **Automatic**: Let's Encrypt certificates via cert-manager
- **Renewal**: Automatic renewal 30 days before expiry
- **Security**: Modern TLS 1.3 with strong ciphers

### Container Security

- Non-root containers
- Read-only filesystems where possible
- Capability dropping
- Resource limits and requests

## 🚀 GitOps with ArgoCD

### ArgoCD Configuration

ArgoCD is automatically configured for:
- **Repository**: Your Git repository
- **Target**: Kubernetes cluster
- **Sync Policy**: Automated with self-heal
- **Environments**: staging, production

### ArgoCD Access

```bash
# Get ArgoCD password
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d

# Port forward to ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Access ArgoCD at https://localhost:8080

## 🔧 Troubleshooting

### Common Issues

1. **Pods not starting**
   ```bash
   kubectl describe pod <pod-name> -n eduai
   kubectl logs <pod-name> -n eduai
   ```

2. **Ingress not working**
   ```bash
   kubectl get ingress -n eduai
   kubectl describe ingress ailearn-ingress -n eduai
   ```

3. **TLS certificate issues**
   ```bash
   kubectl get certificate -n eduai
   kubectl describe certificate ailearn-tls -n eduai
   ```

4. **Minikube issues**
   ```bash
   minikube status
   minikube delete && minikube start
   ```

### Debug Commands

```bash
# Check all resources
kubectl get all -n eduai

# Check events
kubectl get events -n eduai --sort-by='.lastTimestamp'

# Check logs
kubectl logs -f deployment/backend -n eduai

# Exec into pod
kubectl exec -it deployment/backend -n eduai -- /bin/bash
```

### Performance Issues

```bash
# Check resource usage
kubectl top pods -n eduai

# Check HPA status
kubectl describe hpa -n eduai

# Scale manually
kubectl scale deployment backend --replicas=5 -n eduai
```

## 📈 Scaling and Performance

### Horizontal Pod Autoscaling

The deployment includes HPA for:
- **Backend**: 3-20 replicas based on CPU/memory
- **AI Service**: 2-10 replicas based on CPU
- **Frontend**: 2-5 replicas based on CPU

### Resource Limits

| Component | CPU | Memory | Storage |
|-----------|-----|--------|---------|
| Backend   | 500m | 512Mi  | -       |
| Frontend  | 200m | 256Mi  | -       |
| AI Service| 1000m| 2Gi    | -       |
| PostgreSQL| 250m | 512Mi  | 20Gi    |
| Redis     | 100m | 256Mi  | 5Gi     |

## 🔄 Updates and Maintenance

### Application Updates

```bash
# Update application
git pull origin main
./deploy.sh deploy
```

### Kubernetes Updates

```bash
# Update minikube
minikube update

# Update cluster
minikube delete
./deploy.sh
```

### Backup Strategy

- **PostgreSQL**: Daily automated backups
- **Redis**: AOF persistence
- **ConfigMaps**: Git version control
- **Secrets**: External secret management

## 🎯 Production Considerations

### Resource Requirements

- **CPU**: 4 cores minimum
- **Memory**: 8GB minimum
- **Storage**: 50GB minimum
- **Network**: Stable internet connection

### Performance Optimization

- Right-size containers
- Use resource requests/limits
- Implement HPA
- Monitor and tune regularly

### Backup and Recovery

- Regular database backups
- Configuration backups
- Disaster recovery plan
- Testing restoration procedures

## 📞 Support

For issues and questions:

1. Check the troubleshooting section
2. Review deployment logs
3. Check Kubernetes events
4. Consult the documentation
5. Contact the DevOps team

---

**🎉 Your AI Smart Learning Platform is now deployed automatically!**

Visit https://ailearn.duckdns.org to access your platform.
