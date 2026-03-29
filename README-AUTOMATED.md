# 🚀 AI Smart Learning Platform - Fully Automated DevOps

## 🎯 Quick Start

### 1. Full Deployment (First Time)
```bash
./devops.sh
```

After running, open: **https://ailearn.duckdns.org**

### 2. Daily Usage (Fast Startup)
```bash
./run.sh
```

## 🌐 Automated Cloudflare Tunnel

The system automatically configures Cloudflare Tunnel to expose your application to the internet.

### Prerequisites
- Domain: `ailearn.duckdns.org` (already configured)
- Cloudflare account with tunnel credentials
- Place tunnel credentials in: `~/.cloudflared/<tunnel-id>.json`

### What's Automated
- ✅ Minikube cluster setup
- ✅ Docker image building
- ✅ Kubernetes deployment
- ✅ Cloudflare Tunnel configuration
- ✅ Self-healing capabilities
- ✅ Zero manual steps required

## 📁 Clean Architecture

```
ai-smart-learning-platform/
├── devops.sh              # Full automated deployment
├── run.sh                 # Fast daily startup
├── frontend/              # React frontend
├── backend/               # Node.js backend
└── ai-service/            # Python AI service
```

## 🔧 System Requirements

- **CPU**: ≥ 2 cores
- **RAM**: ≥ 4GB
- **Tools**: docker, kubectl, minikube, helm, cloudflared

## 🌐 Access URLs

After deployment:
- **External**: https://ailearn.duckdns.org
- **Frontend**: http://localhost:30007
- **Backend**: http://localhost:30008

## 🛠️ Management Commands

```bash
# Check tunnel logs
tail -f ~/.cloudflared/tunnel.log

# Restart tunnel
pkill -f cloudflared && ./run.sh

# Check pods
kubectl get pods -n eduai

# Full redeploy
./devops.sh

# Stop system
pkill -f cloudflared && minikube stop -p eduai-cluster
```

## 🔄 Self-Healing

The system includes automatic self-healing:
- Restarts failed pods
- Restarts stopped tunnel
- Ensures high availability

## 📊 Features

- ✅ Fully automated deployment
- ✅ Cloudflare Tunnel integration
- ✅ Self-healing capabilities
- ✅ Fast daily startup (<15 seconds)
- ✅ Production-ready configuration
- ✅ Zero manual configuration required

---

**Built for automation and reliability** 🚀
