# Production-Grade Kubernetes Monitoring Stack

## Quick Start Guide

### Prerequisites
- Minikube running
- kubectl configured
- Internet access

### One-Command Installation
```bash
chmod +x setup-monitoring-stack.sh
./setup-monitoring-stack.sh --install
```

### Access Information
After installation, you'll see:
- **Grafana**: http://[MINIKUBE_IP]:30010 (admin/admin)
- **Prometheus**: Port-forward to 9090
- **AlertManager**: Port-forward to 9093

### Port Forwarding (Optional)
```bash
./setup-monitoring-stack.sh --port-forward
```

### Verify Installation
```bash
./setup-monitoring-stack.sh --verify
```

### Debugging Commands
```bash
# Debug dashboard issues
./setup-monitoring-stack.sh --debug-dashboard

# Debug Prometheus scraping
./setup-monitoring-stack.sh --debug-prometheus

# Debug Grafana access
./setup-monitoring-stack.sh --debug-grafana
```

### Cleanup
```bash
./setup-monitoring-stack.sh --cleanup
```

## Pre-Configured Dashboards

The setup includes these production dashboards:
- Kubernetes Cluster Monitoring
- Node Exporter Full
- Pod/Namespace metrics
- API Server metrics
- Compute Resources
- Network Monitoring
- State Metrics

## Manual Commands

### Install Helm (if needed)
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### Add Repository
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

### Install Stack
```bash
helm install kube-prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set grafana.adminPassword=admin \
  --set grafana.service.type=NodePort \
  --set grafana.service.nodePort=30010
```

### Get URLs
```bash
echo "Grafana: http://$(minikube ip):30010"
echo "Username: admin"
echo "Password: admin"
```

## Troubleshooting

### Grafana Not Accessible
1. Check pod status: `kubectl get pods -n monitoring`
2. Check service: `kubectl get svc -n monitoring`
3. Check logs: `kubectl logs -n monitoring -l app.kubernetes.io/name=kube-prometheus-stack-grafana`

### Dashboards Empty
1. Check datasources in Grafana UI
2. Verify Prometheus is scraping: `kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090`
3. Check ServiceMonitors: `kubectl get servicemonitors -n monitoring`

### Prometheus Not Scraping
1. Check targets: http://localhost:9090/api/v1/targets
2. Verify ServiceMonitors are configured
3. Check Prometheus configuration

## Production Features

- **Persistence**: 8Gi for Prometheus, 2Gi for Grafana
- **Retention**: 30 days for metrics
- **Resources**: Optimized for Minikube
- **Security**: TLS enabled for Prometheus
- **Alerting**: AlertManager with webhooks
- **Dashboards**: Pre-imported production dashboards
- **Auto-discovery**: Kubernetes services automatically discovered
