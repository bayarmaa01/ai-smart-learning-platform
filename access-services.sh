#!/bin/bash

set -e

echo "🚀 SERVICE ACCESS SETUP"
echo "======================"
echo ""

# Check if Minikube is running
if ! minikube status -p eduai-cluster | grep -q "Running"; then
    echo "❌ Minikube is not running. Please run:"
    echo "   ./start-dev.sh"
    exit 1
fi

# Set context
kubectl config use-context eduai-cluster

# Get Minikube IP
MINIKUBE_IP=$(minikube ip -p eduai-cluster)

echo "🌐 ACCESS URLS:"
echo "==============="
echo ""

# Frontend
echo "📱 Frontend Application:"
echo "   Local: http://$MINIKUBE_IP:30007"
echo "   External: https://ailearn.duckdns.org"
echo ""

# Backend
echo "🔧 Backend API:"
echo "   Local: http://$MINIKUBE_IP:30008"
echo "   External: https://ailearn.duckdns.org/api"
echo ""

# ArgoCD
echo "⚙️ ArgoCD:"
ARGOCD_PORT=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30007")
echo "   Local: http://$MINIKUBE_IP:$ARGOCD_PORT"
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d 2>/dev/null || echo "admin")
echo "   Credentials: admin/$ARGOCD_PASSWORD"
echo ""

# Grafana
echo "📊 Grafana:"
GRAFANA_PORT=$(kubectl get svc monitoring-grafana -n monitoring -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30008")
echo "   Local: http://$MINIKUBE_IP:$GRAFANA_PORT"
echo "   Credentials: admin/admin123"
echo ""

# Prometheus
echo "📈 Prometheus:"
PROMETHEUS_PORT=$(kubectl get svc monitoring-kube-prometheus-prometheus -n monitoring -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30009")
echo "   Local: http://$MINIKUBE_IP:$PROMETHEUS_PORT"
echo ""

echo "🔍 PORT FORWARD COMMANDS:"
echo "========================"
echo ""
echo "# Forward frontend to localhost:3000"
echo "kubectl port-forward svc/frontend -n eduai 3000:3000"
echo ""
echo "# Forward backend to localhost:5000"
echo "kubectl port-forward svc/backend -n eduai 5000:5000"
echo ""
echo "# Forward ArgoCD to localhost:8080"
echo "kubectl port-forward svc/argocd-server -n argocd 8080:80"
echo ""
echo "# Forward Grafana to localhost:3001"
echo "kubectl port-forward svc/monitoring-grafana -n monitoring 3001:3000"
echo ""

echo "📊 SERVICE STATUS:"
echo "================"
kubectl get svc -n eduai
kubectl get svc -n argocd
kubectl get svc -n monitoring

echo ""
echo "✅ All services are accessible via the URLs above!"
