# EduAI Platform - Deployment Guide

## Table of Contents
- [Production Deployment](#production-deployment)
- [Staging Deployment](#staging-deployment)
- [Local Development](#local-development)
- [Environment Setup](#environment-setup)
- [Security Configuration](#security-configuration)
- [Monitoring Setup](#monitoring-setup)
- [Backup & Recovery](#backup--recovery)
- [Troubleshooting](#troubleshooting)

---

## Production Deployment

### Prerequisites
- Kubernetes cluster (v1.29+)
- Helm 3.14+
- kubectl configured
- Domain name configured
- SSL certificates (or use cert-manager)

### 1. Infrastructure Preparation

```bash
# Create namespace
kubectl create namespace eduai-production

# Add required Helm repositories
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add jetstack https://charts.jetstack.io
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install cert-manager for SSL
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true
```

### 2. Create Secrets

⚠️ **Never commit secrets to Git!** Use Kubernetes secrets or external secret management.

```bash
# Create main secrets
kubectl create secret generic eduai-secrets \
  --from-literal=DB_PASSWORD="your_secure_db_password" \
  --from-literal=JWT_SECRET="your_jwt_secret_min_32_chars" \
  --from-literal=JWT_REFRESH_SECRET="your_refresh_secret_min_32_chars" \
  --from-literal=REDIS_PASSWORD="your_redis_password" \
  --from-literal=MINIO_PASSWORD="your_minio_password" \
  --from-literal=OPENAI_API_KEY="sk-your-openai-key" \
  --from-literal=ANTHROPIC_API_KEY="sk-ant-your-key" \
  --from-literal=HUGGINGFACE_API_KEY="hf-your-key" \
  --namespace eduai-production

# Create TLS secret (if using custom certificates)
kubectl create secret tls eduai-tls \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key \
  --namespace eduai-production
```

### 3. Deploy Database Layer

```bash
# Deploy PostgreSQL with High Availability
helm install postgres bitnami/postgresql \
  --namespace eduai-production \
  --set auth.postgresPassword="your_secure_db_password" \
  --set auth.database="eduai_db" \
  --set primary.persistence.size="100Gi" \
  --set primary.resources.requests.memory="2Gi" \
  --set primary.resources.requests.cpu="1000m" \
  --set readReplicas.replicaCount=2 \
  --set readReplicas.persistence.size="100Gi" \
  --values helm/postgres-values.yaml

# Deploy Redis Cluster
helm install redis bitnami/redis \
  --namespace eduai-production \
  --set auth.password="your_redis_password" \
  --set master.persistence.size="20Gi" \
  --set replica.replicaCount=3 \
  --set cluster.enabled=true \
  --values helm/redis-values.yaml
```

### 4. Deploy Application

```bash
# Deploy main application
helm upgrade --install eduai ./helm/eduai \
  --namespace eduai-production \
  --values helm/production-values.yaml \
  --set global.imageRegistry="your-registry.io" \
  --set global.imageTag="v1.0.0" \
  --set ingress.enabled=true \
  --set ingress.host="eduai.yourdomain.com" \
  --set ingress.tls.enabled=true \
  --wait --timeout=10m
```

### 5. Deploy Monitoring

```bash
# Deploy Prometheus + Grafana
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values helm/monitoring-values.yaml \
  --set grafana.adminPassword="your_grafana_password"

# Deploy ELK Stack for logging
helm install elasticsearch elastic/elasticsearch \
  --namespace logging \
  --create-namespace \
  --values helm/elasticsearch-values.yaml

helm install kibana elastic/kibana \
  --namespace logging \
  --values helm/kibana-values.yaml

helm install logstash elastic/logstash \
  --namespace logging \
  --values helm/logstash-values.yaml
```

---

## Staging Deployment

Staging environment mirrors production but with reduced resources:

```bash
# Create staging namespace
kubectl create namespace eduai-staging

# Deploy with staging configuration
helm upgrade --install eduai-staging ./helm/eduai \
  --namespace eduai-staging \
  --values helm/staging-values.yaml \
  --set global.imageRegistry="your-registry.io" \
  --set ingress.host="eduai-staging.yourdomain.com"
```

---

## Local Development

### Docker Compose (Recommended for Development)

```bash
# Clone repository
git clone https://github.com/your-org/ai-smart-learning-platform.git
cd ai-smart-learning-platform

# Copy environment files
cp backend/env.example backend/.env
cp ai-service/env.example ai-service/.env
cp frontend/.env.example frontend/.env

# Edit environment files with your configurations

# Start all services
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f backend
```

### Individual Services (Development Mode)

```bash
# Terminal 1: Start infrastructure
docker compose up -d postgres redis minio elasticsearch

# Terminal 2: Backend
cd backend
npm install
npm run dev

# Terminal 3: AI Service
cd ai-service
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --reload --port 8000

# Terminal 4: Frontend
cd frontend
npm install
npm run dev
```

---

## Environment Setup

### Production Environment Variables

#### Backend (.env)
```env
NODE_ENV=production
PORT=5000
DB_HOST=postgres
DB_PASSWORD=your_secure_password
JWT_SECRET=your_jwt_secret_min_32_chars
REDIS_URL=redis://:your_redis_password@redis:6379
AI_SERVICE_URL=http://ai-service:8000
```

#### AI Service (.env)
```env
DEBUG=false
AI_PROVIDER=ollama  # or huggingface for free option
OLLAMA_BASE_URL=http://ollama:11434
DATABASE_URL=postgresql://postgres:password@postgres:5432/eduai_db
REDIS_URL=redis://:password@redis:6379
```

#### Frontend (.env)
```env
VITE_API_URL=https://api.yourdomain.com/api/v1
VITE_AI_URL=https://ai.yourdomain.com
VITE_APP_NAME=EduAI Platform
```

---

## Security Configuration

### 1. SSL/TLS Setup

#### Using cert-manager (Let's Encrypt)
```yaml
# cert-manager-issuer.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@yourdomain.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: nginx
```

#### Manual SSL Certificate
```bash
# Generate CSR
openssl req -new -newkey rsa:2048 -nodes -keyout tls.key -out tls.csr -subj "/CN=eduai.yourdomain.com"

# Create secret
kubectl create secret tls eduai-tls \
  --cert=tls.crt \
  --key=tls.key \
  --namespace eduai-production
```

### 2. Network Policies

```yaml
# network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: eduai-network-policy
  namespace: eduai-production
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: ingress-nginx
      ports:
        - protocol: TCP
          port: 5000
        - protocol: TCP
          port: 8000
```

### 3. Pod Security Policies

```yaml
# pod-security-policy.yaml
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: eduai-psp
spec:
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
    - ALL
  volumes:
    - 'configMap'
    - 'emptyDir'
    - 'projected'
    - 'secret'
    - 'downwardAPI'
    - 'persistentVolumeClaim'
  runAsUser:
    rule: 'MustRunAsNonRoot'
  seLinux:
    rule: 'RunAsAny'
  fsGroup:
    rule: 'RunAsAny'
```

---

## Monitoring Setup

### 1. Prometheus Configuration

```yaml
# prometheus-values.yaml
prometheus:
  prometheusSpec:
    retention: 30d
    resources:
      requests:
        memory: 2Gi
        cpu: 1000m
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: fast-ssd
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 100Gi

grafana:
  adminPassword: your_secure_password
  persistence:
    enabled: true
    size: 10Gi
  sidecar:
    dashboards:
      enabled: true
    datasources:
      enabled: true
```

### 2. Alerting Rules

```yaml
# alerting-rules.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: eduai-alerts
  namespace: monitoring
spec:
  groups:
    - name: eduai.rules
      rules:
        - alert: HighErrorRate
          expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: High error rate detected
            description: "Error rate is {{ $value }} errors per second"

        - alert: HighMemoryUsage
          expr: container_memory_usage_bytes / container_spec_memory_limit_bytes > 0.9
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: High memory usage
            description: "Memory usage is above 90%"
```

---

## Backup & Recovery

### 1. Database Backup

```bash
# Create backup CronJob
kubectl apply -f k8s/postgres-backup-cronjob.yaml

# Manual backup
kubectl create job --from=cronjob/postgres-backup manual-backup-$(date +%Y%m%d) -n eduai-production

# Restore from backup
kubectl exec -it postgres-0 -n eduai-production -- psql -U postgres -d eduai_db < backup.sql
```

### 2. Redis Backup

```bash
# Redis backup script
kubectl exec -it redis-master-0 -n eduai-production -- redis-cli BGSAVE
kubectl cp redis-master-0:/data/dump.sql ./redis-backup.sql
```

### 3. Disaster Recovery Plan

1. **Data Loss Recovery**
   - Restore from latest database backup
   - Restore Redis cache if needed
   - Verify application functionality

2. **Cluster Recovery**
   - Deploy fresh Kubernetes cluster
   - Restore PVCs from backups
   - Re-deploy applications
   - Verify all services

---

## Troubleshooting

### Common Issues

#### 1. Pod Not Starting
```bash
# Check pod status
kubectl get pods -n eduai-production

# Check pod logs
kubectl logs <pod-name> -n eduai-production

# Describe pod for detailed info
kubectl describe pod <pod-name> -n eduai-production
```

#### 2. Service Not Accessible
```bash
# Check service endpoints
kubectl get endpoints -n eduai-production

# Check ingress status
kubectl get ingress -n eduai-production

# Test service connectivity
kubectl run test-pod --image=busybox --rm -it --restart=Never -- wget -qO- http://service-name:port
```

#### 3. Database Connection Issues
```bash
# Test database connectivity
kubectl exec -it postgres-0 -n eduai-production -- psql -U postgres -d eduai_db -c "SELECT 1;"

# Check database logs
kubectl logs postgres-0 -n eduai-production
```

#### 4. High CPU/Memory Usage
```bash
# Check resource usage
kubectl top pods -n eduai-production

# Check HPA status
kubectl get hpa -n eduai-production

# Scale manually if needed
kubectl scale deployment backend --replicas=5 -n eduai-production
```

### Performance Tuning

#### 1. Database Optimization
```sql
-- Add indexes for better performance
CREATE INDEX CONCURRENTLY idx_users_email ON users(email);
CREATE INDEX CONCURRENTLY idx_courses_active ON courses(is_active);
CREATE INDEX CONCURRENTLY idx_enrollments_user ON enrollments(user_id);

-- Analyze table statistics
ANALYZE users;
ANALYZE courses;
ANALYZE enrollments;
```

#### 2. Redis Optimization
```bash
# Monitor Redis memory
redis-cli info memory

# Optimize Redis configuration
redis-cli config set maxmemory-policy allkeys-lru
redis-cli config set maxmemory 2gb
```

#### 3. Application Scaling
```yaml
# HPA configuration
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: backend-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: backend
  minReplicas: 3
  maxReplicas: 20
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
```

---

## Maintenance

### Rolling Updates

```bash
# Update application with zero downtime
helm upgrade eduai ./helm/eduai \
  --namespace eduai-production \
  --values helm/production-values.yaml \
  --set global.imageTag="v1.1.0"

# Rollback if needed
helm rollback eduai 1 -n eduai-production
```

### Health Checks

```bash
# Check all services health
kubectl get pods -n eduai-production -o wide
kubectl get services -n eduai-production
kubectl get ingress -n eduai-production

# Run health check script
./scripts/health-check.sh
```

### Log Analysis

```bash
# View application logs
kubectl logs -f deployment/backend -n eduai-production
kubectl logs -f deployment/ai-service -n eduai-production

# Search logs for errors
kubectl logs deployment/backend -n eduai-production | grep ERROR

# View logs in Kibana
# Access: https://kibana.yourdomain.com
```

---

## Security Best Practices

1. **Regular Updates**: Keep all dependencies and Kubernetes versions updated
2. **Secrets Management**: Use external secret management (HashiCorp Vault, AWS Secrets Manager)
3. **Network Segmentation**: Implement proper network policies
4. **RBAC**: Use principle of least privilege for service accounts
5. **Image Scanning**: Scan all container images for vulnerabilities
6. **Audit Logging**: Enable audit logging for all API servers
7. **Backup Encryption**: Encrypt all backup data
8. **Multi-Factor Authentication**: Enable MFA for all admin access

---

## Support

For production support:
- Email: support@yourdomain.com
- Documentation: https://docs.yourdomain.com
- Status Page: https://status.yourdomain.com
- Emergency: +1-555-EDUAI-HELP
