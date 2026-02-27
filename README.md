# EduAI Platform — AI-Powered Online Learning Platform

> Production-ready, cloud-native, multi-tenant SaaS learning platform supporting **10,000+ concurrent users** with **multilingual AI** (English + Mongolian).

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        INTERNET / CDN                           │
└─────────────────────────┬───────────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────────┐
│              NGINX Ingress / Load Balancer (TLS)                │
└──────┬──────────────────┬──────────────────────┬───────────────┘
       │                  │                      │
┌──────▼──────┐  ┌────────▼────────┐  ┌─────────▼──────────┐
│  Frontend   │  │  Backend API    │  │   AI Microservice  │
│  React.js   │  │  Node.js/Express│  │   Python FastAPI   │
│  TailwindCSS│  │  JWT + RBAC     │  │   LLM + NLP        │
│  Redux      │  │  Multi-tenant   │  │   EN + MN Support  │
│  i18n EN/MN │  │  Rate Limiting  │  │   Recommendations  │
└─────────────┘  └────────┬────────┘  └────────────────────┘
                          │
          ┌───────────────┼───────────────┐
          │               │               │
   ┌──────▼──────┐ ┌──────▼──────┐ ┌─────▼──────┐
   │ PostgreSQL  │ │   Redis     │ │    S3/     │
   │  (Primary + │ │   Cache     │ │   MinIO    │
   │   Replica)  │ │   Sessions  │ │   Storage  │
   └─────────────┘ └─────────────┘ └────────────┘
```

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| **Frontend** | React 18, TailwindCSS, Redux Toolkit, i18next (EN+MN), Vite |
| **Backend** | Node.js 20, Express.js, JWT, Helmet, Rate Limiting |
| **AI Service** | Python 3.11, FastAPI, OpenAI/Anthropic/Ollama, LangDetect |
| **Database** | PostgreSQL 15 with connection pooling |
| **Cache** | Redis 7 |
| **Storage** | AWS S3 / MinIO |
| **Search** | Elasticsearch 8 |
| **Container** | Docker, Docker Compose |
| **Orchestration** | Kubernetes, Helm |
| **IaC** | Terraform (AWS EKS, RDS, ElastiCache, S3, CloudFront) |
| **Config Mgmt** | Ansible |
| **CI/CD** | GitHub Actions + Argo CD (GitOps) |
| **Monitoring** | Prometheus + Grafana |
| **Logging** | ELK Stack (Elasticsearch + Logstash + Kibana) |
| **Alerting** | Alertmanager + Slack + Email |

---

## Prerequisites — Software Installation

### Windows (PowerShell as Administrator)

```powershell
# 1. Install Chocolatey (Windows package manager)
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# 2. Install Docker Desktop
choco install docker-desktop -y
# OR download from: https://www.docker.com/products/docker-desktop/

# 3. Install Node.js 20 LTS
choco install nodejs-lts -y
# OR download from: https://nodejs.org/en/download/

# 4. Install Python 3.11
choco install python311 -y
# OR download from: https://www.python.org/downloads/

# 5. Install kubectl
choco install kubernetes-cli -y
# OR: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/

# 6. Install Minikube (local Kubernetes)
choco install minikube -y
# OR: https://minikube.sigs.k8s.io/docs/start/

# 7. Install Helm
choco install kubernetes-helm -y
# OR: https://helm.sh/docs/intro/install/

# 8. Install Terraform
choco install terraform -y
# OR: https://developer.hashicorp.com/terraform/downloads

# 9. Install Argo CD CLI
choco install argocd -y
# OR: https://argo-cd.readthedocs.io/en/stable/cli_installation/

# 10. Install Git
choco install git -y

# Verify installations
node --version        # v20.x.x
python --version      # Python 3.11.x
docker --version      # Docker 25.x.x
kubectl version       # v1.29.x
helm version          # v3.14.x
terraform version     # v1.6.x
```

### macOS

```bash
# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install all tools
brew install node@20 python@3.11 kubectl helm terraform git
brew install --cask docker minikube

# Install Argo CD CLI
brew install argocd
```

### Linux (Ubuntu/Debian)

```bash
# Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Python 3.11
sudo apt-get install -y python3.11 python3.11-pip python3.11-venv

# Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Argo CD CLI
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
```

---

## Quick Start — Local Development

### 1. Clone and Setup

```bash
git clone https://github.com/your-org/ai-smart-learning-platform.git
cd ai-smart-learning-platform

# Copy environment files
cp backend/.env.example backend/.env
cp ai-service/.env.example ai-service/.env
```

### 2. Configure Environment Variables

Edit `backend/.env`:
```env
JWT_SECRET=your_super_secret_jwt_key_min_32_chars
JWT_REFRESH_SECRET=your_refresh_secret_min_32_chars
DB_PASSWORD=your_db_password
```

Edit `ai-service/.env`:
```env
AI_PROVIDER=openai          # or: anthropic | ollama | mock
OPENAI_API_KEY=sk-your-key  # Get from: https://platform.openai.com
```

### 3. Run with Docker Compose

```bash
# Start all services
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f backend
docker compose logs -f ai-service

# Stop all services
docker compose down
```

**Services will be available at:**
| Service | URL |
|---------|-----|
| Frontend | http://localhost:3000 |
| Backend API | http://localhost:5000 |
| AI Service | http://localhost:8000 |
| API Docs | http://localhost:8000/docs |
| Grafana | http://localhost:3001 (admin/admin) |
| Kibana | http://localhost:5601 |
| MinIO Console | http://localhost:9001 |

### 4. Run Services Individually (Development)

```bash
# Terminal 1: Start infrastructure
docker compose up -d postgres redis minio

# Terminal 2: Backend
cd backend
npm install
npm run dev

# Terminal 3: AI Service
cd ai-service
python -m venv venv
# Windows:
venv\Scripts\activate
# macOS/Linux:
source venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload --port 8000

# Terminal 4: Frontend
cd frontend
npm install
npm run dev
```

---

## Kubernetes Deployment

### Local (Minikube)

```bash
# Start Minikube
minikube start --cpus=4 --memory=8192 --driver=docker

# Enable addons
minikube addons enable ingress
minikube addons enable metrics-server

# Build images in Minikube context
eval $(minikube docker-env)  # Linux/macOS
# Windows PowerShell:
# & minikube -p minikube docker-env --shell powershell | Invoke-Expression

docker build -t eduai-frontend:latest ./frontend
docker build -t eduai-backend:latest ./backend
docker build -t eduai-ai-service:latest ./ai-service

# Deploy
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/secrets.yaml      # Edit secrets first!
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/postgres-statefulset.yaml
kubectl apply -f k8s/redis-deployment.yaml
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/ai-service-deployment.yaml
kubectl apply -f k8s/frontend-deployment.yaml
kubectl apply -f k8s/ingress.yaml

# Check status
kubectl get pods -n eduai
kubectl get services -n eduai

# Access via Minikube
minikube service frontend-service -n eduai
```

### Production (Helm)

```bash
# Add Bitnami charts
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Create namespace
kubectl create namespace eduai

# Create secrets (NEVER commit real secrets to git)
kubectl create secret generic eduai-secrets \
  --from-literal=DB_PASSWORD="your_secure_password" \
  --from-literal=JWT_SECRET="your_jwt_secret_min_32_chars" \
  --from-literal=JWT_REFRESH_SECRET="your_refresh_secret" \
  --from-literal=REDIS_PASSWORD="your_redis_password" \
  --from-literal=OPENAI_API_KEY="sk-your-key" \
  -n eduai

# Install/upgrade
helm upgrade --install eduai ./helm/eduai \
  --namespace eduai \
  --values helm/eduai/values.yaml \
  --set global.imageRegistry=your-registry.io \
  --wait --timeout=10m

# Check deployment
helm status eduai -n eduai
kubectl get all -n eduai
```

---

## Argo CD GitOps Setup

```bash
# Install Argo CD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for Argo CD to be ready
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forward (or use Ingress)
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Login
argocd login localhost:8080 --username admin --password <PASSWORD> --insecure

# Create application
argocd app create eduai-production \
  --repo https://github.com/your-org/ai-smart-learning-platform.git \
  --path helm/eduai \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace eduai \
  --sync-policy automated \
  --auto-prune \
  --self-heal

# Sync
argocd app sync eduai-production
```

---

## TLS / HTTPS Setup

### cert-manager (Let's Encrypt)

```bash
# Install cert-manager
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true

# Create ClusterIssuer
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your@email.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: nginx
EOF
```

### Self-signed (Development)

```bash
# Generate self-signed cert
mkdir -p nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout nginx/ssl/tls.key \
  -out nginx/ssl/tls.crt \
  -subj "/CN=localhost/O=EduAI"
```

---

## Terraform Infrastructure

```bash
cd terraform

# Initialize
terraform init

# Plan
terraform plan -var="redis_auth_token=your_redis_token" -out=tfplan

# Apply
terraform apply tfplan

# Destroy (when done)
terraform destroy
```

---

## Monitoring Setup

```bash
# Prometheus + Grafana (Docker Compose)
docker compose up -d prometheus grafana

# Access Grafana: http://localhost:3001
# Default credentials: admin / admin

# Import dashboards (Grafana UI)
# Dashboard IDs to import:
# - 1860 (Node Exporter Full)
# - 6417 (Kubernetes Cluster)
# - 11835 (Redis Dashboard)
# - 9628 (PostgreSQL Database)

# Kubernetes monitoring
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace
```

---

## Database Backup & Recovery

```bash
# Manual backup
docker compose exec postgres pg_dump -U postgres eduai_db > backup_$(date +%Y%m%d).sql

# Restore
docker compose exec -T postgres psql -U postgres eduai_db < backup_20240101.sql

# Kubernetes CronJob backup (already in k8s/postgres-statefulset.yaml)
kubectl get cronjobs -n eduai

# Run backup manually
kubectl create job --from=cronjob/postgres-backup manual-backup-$(date +%Y%m%d) -n eduai
```

---

## Horizontal Auto Scaling

```bash
# Check HPA status
kubectl get hpa -n eduai

# Manual scale
kubectl scale deployment backend --replicas=5 -n eduai

# Load test to trigger autoscaling
kubectl run -i --tty load-generator \
  --image=busybox --restart=Never -- \
  /bin/sh -c "while sleep 0.01; do wget -q -O- http://backend-service:5000/health; done"
```

---

## CI/CD Pipeline

The GitHub Actions pipeline runs on every push:

1. **Unit Tests** — Frontend (Vitest), Backend (Jest), AI Service (Pytest)
2. **SAST Scan** — SonarQube code quality analysis
3. **Build Images** — Multi-stage Docker builds with layer caching
4. **Security Scan** — Trivy container vulnerability scanning
5. **Deploy Staging** — Auto-deploy to staging on `develop` branch
6. **Deploy Production** — GitOps via Argo CD on `main` branch
7. **Notifications** — Slack alerts on success/failure

### Required GitHub Secrets

```
SONAR_TOKEN          - SonarQube token
SONAR_HOST_URL       - SonarQube server URL
CODECOV_TOKEN        - Codecov.io token
ARGOCD_SERVER        - Argo CD server URL
ARGOCD_PASSWORD      - Argo CD admin password
SLACK_WEBHOOK_URL    - Slack webhook for notifications
```

---

## Security Features

| Feature | Implementation |
|---------|---------------|
| Authentication | JWT Access (15min) + Refresh (7d) tokens |
| Authorization | RBAC (student, instructor, admin, super_admin) |
| Rate Limiting | Express-rate-limit (global + per-endpoint) |
| Input Validation | express-validator + Joi |
| XSS Protection | Helmet.js + xss-clean |
| SQL Injection | Parameterized queries |
| HTTPS | TLS 1.2/1.3 via cert-manager |
| Secrets | Kubernetes Secrets (never in git) |
| Container Security | Non-root users, read-only filesystem |
| Dependency Scanning | Trivy in CI/CD |
| Code Analysis | SonarQube SAST |
| Account Lockout | 5 failed attempts → 15min lockout |
| Token Blacklist | Redis-based JWT blacklisting on logout |

---

## Multilingual Support (EN + MN)

The platform fully supports **English** and **Mongolian** (Монгол):

- **Language Switcher**: `EN | MN` button in navbar and auth pages
- **Auto-persist**: Selected language saved to `localStorage`
- **AI Chat**: Automatically detects input language and responds accordingly
- **All Pages**: Login, Register, Dashboard, Courses, Admin, AI Chat

### Adding a New Language

1. Create `frontend/src/i18n/locales/XX.json` (copy from `en.json`)
2. Add to `frontend/src/i18n/index.js`:
   ```js
   import xxTranslations from './locales/xx.json';
   resources: { xx: { translation: xxTranslations } }
   ```
3. Update `LanguageSwitcher.jsx` to include the new language

---

## API Documentation

When running in development mode, FastAPI auto-generates docs:
- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

### Key API Endpoints

```
POST   /api/v1/auth/register       - Register new user
POST   /api/v1/auth/login          - Login
POST   /api/v1/auth/refresh        - Refresh access token
GET    /api/v1/auth/me             - Get current user

GET    /api/v1/courses             - List courses (with filters)
GET    /api/v1/courses/:id         - Get course details
POST   /api/v1/courses/:id/enroll  - Enroll in course
POST   /api/v1/courses/:id/progress - Update lesson progress

POST   /api/v1/ai/chat             - AI chat (EN/MN)
GET    /api/v1/ai/chat/history/:id - Get chat history
POST   /api/v1/ai/recommendations  - Get AI recommendations

GET    /api/v1/subscriptions/plans - List subscription plans
POST   /api/v1/subscriptions/subscribe - Subscribe to plan

GET    /api/v1/admin/stats         - Admin statistics (admin only)
GET    /api/v1/admin/users         - List users (admin only)
```

---

## Project Structure

```
ai-smart-learning-platform/
├── frontend/                    # React.js SPA
│   ├── src/
│   │   ├── i18n/               # EN + MN translations
│   │   ├── store/              # Redux Toolkit slices
│   │   ├── pages/              # Route pages
│   │   ├── components/         # Reusable components
│   │   ├── layouts/            # Page layouts
│   │   └── services/           # API service layer
│   ├── Dockerfile
│   └── nginx.conf
├── backend/                     # Node.js Express API
│   ├── src/
│   │   ├── controllers/        # Route handlers
│   │   ├── routes/             # Express routes
│   │   ├── middleware/         # Auth, validation, errors
│   │   ├── db/                 # PostgreSQL + schema
│   │   ├── cache/              # Redis client
│   │   ├── monitoring/         # Prometheus metrics
│   │   └── websocket/          # Socket.IO
│   └── Dockerfile
├── ai-service/                  # Python FastAPI AI
│   ├── app/
│   │   ├── routers/            # API routes
│   │   ├── services/           # LLM, language detection
│   │   └── core/               # Config, Redis, logging
│   ├── main.py
│   └── Dockerfile
├── k8s/                         # Kubernetes manifests
├── helm/eduai/                  # Helm chart
├── terraform/                   # AWS infrastructure
├── ansible/                     # Server configuration
├── monitoring/                  # Prometheus + Grafana
├── nginx/                       # NGINX config
├── .github/workflows/           # GitHub Actions CI/CD
└── docker-compose.yml           # Local development
```

---

## Demo Credentials

| Role | Email | Password |
|------|-------|----------|
| Student | student@demo.com | Demo@1234 |
| Admin | admin@demo.com | Admin@1234 |

---

## License

MIT License — See [LICENSE](LICENSE) for details.
