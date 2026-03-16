# EDUAI - Production Grade DevOps Platform

## Overview

This guide provides a complete production-grade Kubernetes DevOps platform for the EDUAI AI Smart Learning Platform, following modern DevOps best practices used by AI startups.

## 🏗️ Architecture

### Microservices
- **Frontend**: React/Next.js application (Port 80)
- **Backend**: Node.js REST API (Port 5000)
- **AI Service**: Python FastAPI microservice (Port 8000)

### Infrastructure
- **PostgreSQL**: Primary database with persistent storage
- **Redis**: Cache and session storage
- **MinIO**: Object storage for file uploads (local dev)

### Platform Configuration
- **Domain**: `ailearn.duckdns.org`
- **Docker Registry**: `bayarmaa`
- **Images**: `bayarmaa/eduai-*:latest`

## 🚀 Quick Start

### Local Development
```bash
# Deploy complete platform
chmod +x deploy.sh
./deploy.sh
```

### Production Deployment
```bash
# Deploy to production cluster
./deploy.sh deploy
```

## 📋 Deployment Script Features

### ✅ Core Capabilities
- **Auto Minikube Setup**: Detects and starts cluster automatically
- **Docker BuildKit**: Multi-arch builds with caching
- **Smart Push**: Skips Docker Hub push when running locally
- **Manifest-Based**: Uses existing K8s manifests from `k8s/` directory
- **Production Monitoring**: Full Prometheus + Grafana + Loki stack
- **TLS Automation**: Let's Encrypt certificates with cert-manager
- **Security**: Network policies and pod security
- **Observability**: Centralized logging and metrics
- **Error Handling**: Comprehensive error handling and retry logic

### 🎯 Script Commands
```bash
# Deploy complete platform
./deploy.sh

# Build images only
./deploy.sh build

# Push images only
./deploy.sh push

# Install monitoring only
./deploy.sh monitor

# Install logging only
./deploy.sh logging

# Verify deployment
./deploy.sh verify

# Clean up everything
./deploy.sh cleanup

# Show help
./deploy.sh help
```

## 📁 Project Structure

```
ai-smart-learning-platform/
├── 📄 Core Scripts
│   ├── deploy.sh              # Main production deployment script
│   ├── build-docker-images.sh # Docker build automation
│   └── setup-local-cluster.sh # Local cluster setup
├── 📁 Source Code
│   ├── frontend/              # React application
│   ├── backend/               # Node.js API
│   └── ai-service/            # Python AI service
├── 📁 Kubernetes Manifests
│   ├── k8s/
│   │   ├── namespace.yaml          # Namespace definitions
│   │   ├── postgres-statefulset.yaml # PostgreSQL deployment
│   │   ├── redis-deployment.yaml      # Redis deployment
│   │   ├── backend-deployment.yaml    # Backend API deployment
│   │   ├── ai-service-deployment.yaml # AI service deployment
│   │   ├── frontend-deployment.yaml   # Frontend deployment
│   │   ├── ingress.yml             # NGINX ingress with TLS
│   │   ├── hpa.yml                # Horizontal Pod Autoscaling
│   │   ├── configmap.yaml          # Application configuration
│   │   ├── eduai-secrets.yaml      # Application secrets
│   │   ├── cert-manager.yaml        # TLS certificate management
│   │   └── network-policy.yaml      # Network security policies
│   └── helm/                   # Helm charts for advanced deployments
├── 📁 CI/CD
│   └── .github/workflows/
│       └── ci-cd.yml          # GitHub Actions pipeline
├── 📁 Infrastructure
│   ├── ansible/               # Configuration management
│   ├── terraform/             # Infrastructure as code
│   └── monitoring/            # Monitoring configurations
└── 📁 Documentation
    ├── README.md               # Main documentation
    ├── README-PROD-DEVOPS.md # This DevOps guide
    └── docs/                  # Additional documentation
```

## 🔧 Deployment Process

### 1. Infrastructure Setup
```bash
# Automatic cluster detection and startup
# Minikube cluster: eduai-cluster
# CPUs: 4, Memory: 6GB, Disk: 50GB
# Docker BuildKit enabled for multi-arch builds
# Auto-connect to Minikube Docker daemon
```

### 2. Build & Deploy
```bash
# Multi-architecture Docker builds
# Platforms: linux/amd64,linux/arm64
# Build caching with BuildKit
# Smart Docker Hub push (skipped for local)
# Manifest-based Kubernetes deployment
```

### 3. Production Services
```bash
# PostgreSQL with persistent storage (20Gi)
# Redis with persistence (5Gi)
# Backend API with HPA (3-20 replicas)
# AI Service with HPA (2-10 replicas)
# Frontend with Nginx optimization
# NGINX Ingress with TLS termination
# Let's Encrypt certificates (automatic renewal)
```

### 4. Monitoring & Observability
```bash
# Prometheus for metrics collection
# Grafana for visualization (admin/admin123)
# Loki for log aggregation
# Promtail for log shipping
# AlertManager for alerting
# Custom dashboards and alerts
```

## 🌐 Access URLs

### Production
- **Frontend**: https://ailearn.duckdns.org
- **Backend API**: https://ailearn.duckdns.org/api
- **AI Service**: https://ailearn.duckdns.org/ai

### Monitoring
- **Grafana**: https://grafana.ailearn.duckdns.org (admin/admin123)
- **Prometheus**: https://prometheus.ailearn.duckdns.org
- **Logs**: https://loki.ailearn.duckdns.org

### Local Development
- **Frontend**: http://localhost:80
- **Backend API**: http://localhost:5000
- **AI Service**: http://localhost:8000
- **Minikube Dashboard**: `minikube dashboard -p eduai-cluster`

## 🔄 CI/CD Pipeline

### GitHub Actions Workflow

#### Stages
1. **Lint & Test**: Code quality and automated testing
2. **SonarCloud Analysis**: Code quality and security analysis
3. **Security Scan**: Vulnerability scanning with Trivy
4. **Build Images**: Multi-architecture Docker builds
5. **Deploy Staging**: Automatic deployment for develop branch
6. **Deploy Production**: Production deployment for main branch
7. **Performance Test**: Load testing with k6
8. **Cleanup**: Remove old Docker images

#### Environment Separation
- **Staging**: `develop` branch → `eduai-staging` namespace
- **Production**: `main` branch → `eduai` namespace
- **Rollback**: Automatic rollback capabilities
- **Notifications**: Slack integration for deployment status

#### Secrets Management
```yaml
# Required GitHub Secrets
DOCKER_USERNAME: bayarmaa
DOCKER_PASSWORD: [Docker Hub password]
KUBE_CONFIG_STAGING: [Kubeconfig for staging]
KUBE_CONFIG_PRODUCTION: [Kubeconfig for production]
SLACK_WEBHOOK: [Slack webhook URL]
SONAR_TOKEN: [SonarCloud token]
```

#### SonarCloud Configuration
```yaml
# Project Settings
Project Key: bayarmaa01_ai-smart-learning-platform
Organization: bayarmaa01
Quality Gate: Enabled
Coverage Target: 80%
Languages: JavaScript, Python
```

#### Quality Gates
```yaml
# Code Quality Requirements
Coverage: > 80%
Maintainability: A rating
Reliability: A rating
Security: A rating
Duplicated Lines: < 3%
Test Success: > 80%
```

## 📊 Monitoring Stack

### Prometheus Configuration
- **Storage**: 50Gi persistent storage
- **Retention**: 15 days
- **Scraping**: Application metrics and Kubernetes metrics
- **Alerting**: Custom alert rules for production

### Grafana Dashboards
- **Application Overview**: Pod health, resource usage
- **API Performance**: Response times, error rates
- **AI Service Metrics**: Inference latency, model performance
- **Infrastructure**: Cluster health, storage usage
- **Business Metrics**: User activity, course completion rates

### Alerting Rules
```yaml
# High CPU usage (>80% for 5 minutes)
# Memory pressure (>90% for 5 minutes)
# Pod crash loops (restarts > 3 in 10 minutes)
# Database latency (>100ms for 2 minutes)
# API error rate (>5% for 5 minutes)
```

## 🔒 Security Implementation

### Network Security
```yaml
# Default deny all ingress/egress
# Allow specific pod-to-pod communication
# Allow DNS resolution (TCP/UDP 53)
# Allow external HTTPS (TCP 443)
# Allow external HTTP (TCP 80)
```

### Pod Security
```yaml
# Non-root containers
# Read-only filesystems where possible
# Capability dropping
# Resource limits and requests
# Security contexts
```

### TLS Management
```yaml
# Let's Encrypt certificates
# Automatic renewal 30 days before expiry
# HTTP01 challenge validation
# NGINX ingress integration
```

## 🚀 Scaling & Performance

### Horizontal Pod Autoscaling
```yaml
# Backend: 3-20 replicas based on CPU/Memory
# AI Service: 2-10 replicas based on CPU
# Target utilization: 70% CPU, 80% Memory
# Scale-up/down policies
```

### Resource Optimization
```yaml
# Frontend: 50-200m CPU, 64-256Mi memory
# Backend: 100-500m CPU, 256-512Mi memory
# AI Service: 200-1000m CPU, 512-2048Mi memory
# PostgreSQL: 250-1000m CPU, 512-2048Mi memory
# Redis: 100-500m CPU, 256-1024Mi memory
```

## 📋 Logging Strategy

### Centralized Logging
```yaml
# Loki for log aggregation
# Promtail for log shipping
# Structured JSON logging
# Log levels: DEBUG, INFO, WARN, ERROR
# Log retention: 30 days
```

### Log Formats
```json
{
  "timestamp": "2024-03-16T12:00:00Z",
  "level": "INFO",
  "service": "backend",
  "pod": "backend-7d4f8b9-xyz",
  "message": "User login successful",
  "user_id": "12345",
  "request_id": "req-abc-123",
  "duration_ms": 150
}
```

## 🔧 Operations

### Daily Operations
```bash
# Check deployment status
./deploy.sh verify

# Monitor resource usage
kubectl top pods -n eduai

# Check logs
kubectl logs -f deployment/backend -n eduai

# Scale applications
kubectl scale deployment backend --replicas=5 -n eduai

# Restart services
kubectl rollout restart deployment/backend -n eduai
```

### Troubleshooting
```bash
# Check pod issues
kubectl describe pod <pod-name> -n eduai

# Check service connectivity
kubectl get endpoints -n eduai

# Debug ingress issues
kubectl describe ingress eduai-ingress -n eduai

# Check certificate status
kubectl get certificate -n eduai
```

## 🚀 Production Deployment

### Cloud Provider Setup

#### AWS EKS
```bash
# Install eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp && sudo mv /tmp/eksctl /usr/local/bin

# Create EKS cluster
eksctl create cluster --name eduai-prod --region us-east-1 --nodegroup-name eduai-nodes --node-type t3.medium --nodes 3 --managed

# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name eduai-prod

# Deploy platform
./deploy.sh deploy
```

#### Google GKE
```bash
# Install gcloud CLI
curl https://sdk.cloud.google.com | bash
export PATH=$PATH:~/google-cloud-sdk/bin:$PATH

# Create GKE cluster
gcloud container clusters create-auto eduai-prod --region us-central1 --num-nodes=3 --machine-type=e2-medium

# Get credentials
gcloud container clusters get-credentials eduai-prod --region us-central1

# Deploy platform
./deploy.sh deploy
```

### Environment Management
```bash
# Production
export KUBECONFIG=~/.kube/eduai-prod
./deploy.sh deploy

# Staging
export KUBECONFIG=~/.kube/eduai-staging
./deploy.sh deploy

# Development
minikube start -p eduai-dev
./deploy.sh deploy
```

## 📈 Performance Optimization

### Database Optimization
```sql
-- Connection pooling
ALTER SYSTEM SET max_connections = 200;

-- Index optimization
CREATE INDEX CONCURRENTLY ON users(email);
CREATE INDEX CONCURRENTLY ON courses(category);
CREATE INDEX CONCURRENTLY ON enrollments(user_id, course_id);

-- Query optimization
EXPLAIN ANALYZE SELECT * FROM users WHERE email = 'test@example.com';
```

### Caching Strategy
```yaml
# Redis caching
- Session storage: 30 minutes TTL
- API response caching: 5 minutes TTL
- Database query caching: 10 minutes TTL
- Static asset caching: 1 hour TTL
```

### CDN Configuration
```yaml
# Static assets via CDN
- Frontend build assets
- API response caching
- Geographic distribution
- Cache hit optimization
```

## 🔮 Future Enhancements

### Planned Features
- [ ] **Multi-cloud support**: AWS, GCP, Azure deployment
- [ ] **GitOps advanced**: ArgoCD with progressive delivery
- [ ] **Service mesh**: Istio for microservice communication
- [ ] **Chaos engineering**: Fault injection testing
- [ ] **Cost optimization**: Resource usage monitoring and optimization
- [ ] **Compliance**: SOC 2 and GDPR compliance automation
- [ ] **ML Ops**: Model monitoring and retraining automation

### Technology Roadmap
- [ ] **Q2 2024**: Service mesh implementation
- [ ] **Q3 2024**: Multi-cloud deployment
- [ ] **Q4 2024**: Advanced monitoring and observability
- [ ] **Q1 2025**: AI-powered operations automation

## 📞 Support & Maintenance

### Monitoring Checklist
- [ ] Daily health checks
- [ ] Weekly performance reviews
- [ ] Monthly security audits
- [ ] Quarterly capacity planning
- [ ] Annual disaster recovery testing

### Backup Strategy
- [ ] Database backups every 6 hours
- [ ] Configuration backups in Git
- [ ] Disaster recovery plan documented
- [ ] Backup restoration tested quarterly

### Security Checklist
- [ ] Vulnerability scanning weekly
- [ ] Dependency updates monthly
- [ ] Security patches applied within 30 days
- [ ] Access reviews quarterly
- [ ] Incident response plan tested

---

## 🎉 Summary

This production-grade DevOps platform provides:

✅ **Complete Automation**: One-command deployment
✅ **Production Ready**: TLS, monitoring, logging, security
✅ **Cloud Native**: Kubernetes best practices
✅ **Scalable**: Auto-scaling and performance optimization
✅ **Observable**: Full monitoring and alerting
✅ **Secure**: Network policies and vulnerability scanning
✅ **CI/CD**: Automated testing and deployment
✅ **Reliable**: Error handling and recovery mechanisms

**Deploy your AI Smart Learning Platform with confidence using modern DevOps practices!** 🚀
