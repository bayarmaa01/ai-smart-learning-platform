# AI Smart Learning Platform - HTTPS Deployment Guide

## Overview

This guide documents the complete HTTPS deployment setup for the AI Smart Learning Platform using Minikube, NGINX Ingress Controller, and Let's Encrypt certificates.

## Prerequisites

### System Requirements
- Minikube installed and running
- Docker Desktop running
- Helm 3.x installed
- Domain: `ailearn.duckdns.org` pointing to your public IP
- Router ports 80 and 443 forwarded to Minikube host

### Software Installation

```bash
# Install Helm (if not installed)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installations
minikube version
helm version
kubectl version
```

## Quick Start

### 1. Deploy with HTTPS (Recommended)

```bash
chmod +x devops-smart-ingress.sh
./devops-smart-ingress.sh full
```

### 2. Access Your Platform

- **HTTPS Domain**: https://ailearn.duckdns.org
- **Default User**: test@test.com / 123456

## Architecture

### Network Flow
```
Internet (HTTPS) 
    |
    v
Router (Port Forwarding 80/443)
    |
    v
Minikube Node
    |
    v
NGINX Ingress Controller (NodePort 30080/30443)
    |
    v
Ingress Rules (ailearn.duckdns.org)
    |
    v
Services:
    - Frontend (port 3000)
    - Backend (port 5000)
    - AI Service (port 8000)
```

### Kubernetes Components

#### 1. Ingress Controller
- **NGINX Ingress Controller**
- NodePort: 30080 (HTTP), 30443 (HTTPS)
- Handles SSL termination and routing

#### 2. Certificate Management
- **cert-manager**: Automatic Let's Encrypt certificates
- **ClusterIssuer**: Production ACME server
- **Certificate**: Auto-renewing TLS certificates

#### 3. Services
- **Frontend**: React app served by NGINX
- **Backend**: Node.js API server
- **AI Service**: Python Flask app connecting to Ollama
- **Database**: PostgreSQL
- **Cache**: Redis

## Configuration Files

### 1. Ingress Configuration (`k8s/ingress.yaml`)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ailearn-ingress
  namespace: eduai
  annotations:
    kubernetes.io/ingress.class: "nginx"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    # Security headers
    nginx.ingress.kubernetes.io/hsts: "true"
    nginx.ingress.kubernetes.io/content-security-policy: "..."
spec:
  tls:
  - hosts:
    - ailearn.duckdns.org
    secretName: ailearn-tls
  rules:
  - host: ailearn.duckdns.org
    http:
      paths:
      - path: /api
        backend:
          service:
            name: backend
            port:
              number: 5000
      - path: /ai
        backend:
          service:
            name: ai-service
            port:
              number: 8000
      - path: /
        backend:
          service:
            name: frontend
            port:
              number: 3000
```

### 2. Certificate Issuer (`k8s/cluster-issuer.yaml`)

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: bayarmaa@example.com
    solvers:
    - http01:
        ingress:
          class: nginx
```

### 3. AI Service (`k8s/ai-service.yaml`)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ai-service
spec:
  template:
    spec:
      containers:
      - name: ai-service
        env:
        - name: OLLAMA_URL
          value: "http://host.minikube.internal:11434"
        - name: MODEL_NAME
          value: "gemma"
        ports:
        - containerPort: 8000
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
```

## Security Features

### 1. HTTPS/SSL
- Automatic Let's Encrypt certificates
- HTTP to HTTPS redirect
- SSL security headers
- HSTS (HTTP Strict Transport Security)

### 2. Security Headers
- Content Security Policy (CSP)
- X-Frame-Options
- X-Content-Type-Options
- Referrer Policy

### 3. Container Security
- Non-root containers (runAsUser: 1001)
- Read-only filesystem
- Drop all Linux capabilities
- Resource limits

## Router Configuration

### Port Forwarding Setup

Forward these ports to your Minikube host:

1. **Port 80** (HTTP) -> Minikube IP:30080
2. **Port 443** (HTTPS) -> Minikube IP:30443

### Example Router Settings
```
External Port 80  -> Internal Port 30080
External Port 443 -> Internal Port 30443
Protocol: TCP
Destination: [Your Minikube Host IP]
```

## Monitoring and Debugging

### 1. Check Ingress Status
```bash
kubectl get ingress -n eduai
kubectl describe ingress ailearn-ingress -n eduai
```

### 2. Check Certificate Status
```bash
kubectl get certificate ailearn-tls -n eduai
kubectl describe certificate ailearn-tls -n eduai
kubectl get certificate -n eduai -o wide
```

### 3. Check cert-manager Logs
```bash
kubectl logs -n cert-manager deployment/cert-manager
kubectl logs -n cert-manager deployment/cert-manager-cainjector
kubectl logs -n cert-manager deployment/cert-manager-webhook
```

### 4. Check NGINX Ingress Logs
```bash
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

### 5. Test Certificate
```bash
# Test HTTPS connection
curl -I https://ailearn.duckdns.org

# Check certificate details
openssl s_client -connect ailearn.duckdns.org:443 -servername ailearn.duckdns.org
```

## Troubleshooting

### Common Issues

#### 1. Certificate Not Issued
```bash
# Check certificate status
kubectl describe certificate ailearn-tls -n eduai

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Check ACME challenges
kubectl get order -n eduai
kubectl describe order <order-name> -n eduai
```

#### 2. Ingress Not Working
```bash
# Check Ingress Controller
kubectl get pods -n ingress-nginx
kubectl get service -n ingress-nginx

# Check Ingress rules
kubectl get ingress -n eduai
kubectl describe ingress ailearn-ingress -n eduai
```

#### 3. Domain Not Accessible
```bash
# Check DNS resolution
nslookup ailearn.duckdns.org

# Check router port forwarding
telnet [your-public-ip] 80
telnet [your-public-ip] 443

# Check Minikube IP
minikube ip
```

#### 4. AI Service Not Working
```bash
# Check AI service logs
kubectl logs -n eduai deployment/ai-service

# Test AI service locally
kubectl exec -n eduai deployment/ai-service -- curl http://localhost:8000/health

# Check Ollama connectivity
kubectl exec -n eduai deployment/ai-service -- curl http://host.minikube.internal:11434/api/tags
```

## API Endpoints

### Frontend
- `https://ailearn.duckdns.org/` - Main application

### Backend API
- `https://ailearn.duckdns.org/api/health` - Health check
- `https://ailearn.duckdns.org/api/v1/auth/login` - Login
- `https://ailearn.duckdns.org/api/v1/auth/register` - Register

### AI Service
- `https://ailearn.duckdns.org/ai/health` - AI service health
- `https://ailearn.duckdns.org/ai/api/v1/ai/chat` - Chat with AI
- `https://ailearn.duckdns.org/ai/api/v1/ai/models` - List available models

## Maintenance

### Certificate Renewal
- cert-manager automatically renews certificates 30 days before expiry
- Monitor renewal with: `kubectl get certificate -n eduai`

### Updates
```bash
# Update application
./devops-smart-ingress.sh fast

# Full redeployment
./devops-smart-ingress.sh full
```

### Backup
```bash
# Backup database
kubectl exec -n eduai deployment/postgres -- pg_dump -U postgres eduai > backup.sql

# Restore database
kubectl exec -i -n eduai deployment/postgres -- psql -U postgres eduai < backup.sql
```

## Performance Optimization

### 1. Resource Limits
All containers have CPU and memory limits defined to prevent resource exhaustion.

### 2. Health Checks
Comprehensive liveness and readiness probes ensure service reliability.

### 3. Auto-scaling
Ready for horizontal pod autoscaling configuration.

## Security Best Practices

1. **Regular Updates**: Keep cert-manager and ingress controller updated
2. **Monitor Logs**: Regularly check cert-manager and ingress logs
3. **Certificate Monitoring**: Monitor certificate expiry and renewal
4. **Network Security**: Use firewall rules to restrict access
5. **Access Control**: Implement RBAC for Kubernetes access

## Support

For issues:
1. Check the troubleshooting section
2. Review logs with the provided commands
3. Verify router port forwarding
4. Ensure domain DNS is correctly configured

The platform is designed to be production-ready with automatic certificate management, security headers, and comprehensive monitoring.
