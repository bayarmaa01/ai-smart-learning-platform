# Cloudflare Tunnel + Kubernetes Deployment Guide

## 🚀 Step-by-Step Commands

### 1. Start Minikube Cluster
```bash
minikube start -p eduai-cluster --driver=docker --memory=4096 --cpus=2 --disk-size=50g --kubernetes-version=v1.28.0 --container-runtime=docker
kubectl config use-context eduai-cluster
```

### 2. Enable Ingress Addon
```bash
minikube addons enable ingress -p eduai-cluster
```

### 3. Create Namespace
```bash
kubectl apply -f namespace.yaml
```

### 4. Deploy Applications
```bash
kubectl apply -f deployments.yaml
kubectl apply -f services.yaml
```

### 5. Create Ingress
```bash
kubectl apply -f ingress.yaml
```

### 6. Update Cloudflare Tunnel Config
```bash
# Copy the config to cloudflared directory
cp cloudflare-tunnel-config.yml ~/.cloudflared/config.yml

# Restart cloudflared service
sudo systemctl restart cloudflared
```

## 🔍 Verification Commands

### Check All Resources
```bash
# Check namespaces
kubectl get namespaces

# Check pods
kubectl get pods -n eduai

# Check services
kubectl get svc -n eduai

# Check ingress
kubectl get ingress -n eduai

# Check ingress controller
kubectl get pods -n ingress-nginx
```

### Detailed Status
```bash
# Get detailed pod information
kubectl describe pods -n eduai

# Get service endpoints
kubectl get endpoints -n eduai

# Get ingress details
kubectl describe ingress eduai-ingress -n eduai

# Check ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
```

## 🐛 Debugging Checklist

### Inside Cluster Testing
```bash
# Test frontend service
kubectl run curl-test --image=curlimages/curl -it --rm --restart=Never -- curl http://frontend.eduai.svc.cluster.local

# Test backend service
kubectl run curl-test --image=curlimages/curl -it --rm --restart=Never -- curl http://backend.eduai.svc.cluster.local:5000

# Test AI service
kubectl run curl-test --image=curlimages/curl -it --rm --restart=Never -- curl http://ai-service.eduai.svc.cluster.local:8000

# Test ingress from inside cluster
kubectl run curl-test --image=curlimages/curl -it --rm --restart=Never -- curl -H "Host: app.ailearn.duckdns.org" http://ingress-nginx-controller.ingress-nginx.svc.cluster.local
```

### Cloudflare Tunnel Testing
```bash
# Check cloudflared status
sudo systemctl status cloudflared

# Check cloudflared logs
sudo journalctl -u cloudflared -f

# Test external connectivity
curl -H "Host: app.ailearn.duckdns.org" http://localhost:8080
curl -H "Host: api.ailearn.duckdns.org" http://localhost:8080
curl -H "Host: ai.ailearn.duckdns.org" http://localhost:8080

# Test via Cloudflare Tunnel
curl https://app.ailearn.duckdns.org
curl https://api.ailearn.duckdns.org
curl https://ai.ailearn.duckdns.org
```

### Port Forwarding for Local Testing
```bash
# Forward ingress controller to local port
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80

# Test with port forwarding
curl -H "Host: app.ailearn.duckdns.org" http://localhost:8080
```

## 🔧 Troubleshooting

### Common Issues

1. **Ingress shows 404**
   - Check ingress controller is running: `kubectl get pods -n ingress-nginx`
   - Check ingress rules: `kubectl describe ingress eduai-ingress -n eduai`
   - Verify service endpoints: `kubectl get endpoints -n eduai`

2. **Cloudflare Tunnel not working**
   - Check cloudflared config: `cat ~/.cloudflared/config.yml`
   - Check cloudflared status: `sudo systemctl status cloudflared`
   - Check cloudflared logs: `sudo journalctl -u cloudflared`

3. **Services not accessible**
   - Check service endpoints: `kubectl get endpoints -n eduai`
   - Check pod status: `kubectl get pods -n eduai`
   - Check pod logs: `kubectl logs -n eduai <pod-name>`

4. **DNS resolution issues**
   - Verify Cloudflare DNS records exist
   - Test with nslookup: `nslookup app.ailearn.duckdns.org`
   - Check tunnel status in Cloudflare dashboard

### Health Check Commands
```bash
# Overall cluster health
kubectl get nodes
kubectl get componentstatuses

# Ingress health
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx

# Application health
kubectl get pods -n eduai
kubectl get svc -n eduai
kubectl get ingress -n eduai
```

## 🎯 Expected Flow

```
User → Cloudflare Tunnel → NGINX Ingress → Service → Pods
     (HTTPS)              (HTTP)          (ClusterIP)   (Containers)
```

**Final URLs:**
- Frontend: https://app.ailearn.duckdns.org
- Backend API: https://api.ailearn.duckdns.org
- AI Service: https://ai.ailearn.duckdns.org
