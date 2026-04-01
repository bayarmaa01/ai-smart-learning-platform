#!/bin/bash

echo "🔍 MINIKUBE STATUS CHECK"
echo "======================"
echo ""

echo "📊 Minikube Status:"
minikube status -p eduai-cluster
echo ""

echo "🌐 Minikube IP:"
minikube ip -p eduai-cluster 2>/dev/null || echo "Cluster not running"
echo ""

echo "🔧 Kubectl Context:"
kubectl config current-context
echo ""

echo "📦 Pod Status:"
kubectl get pods -A
echo ""

echo "🌐 Service Status:"
kubectl get svc -A
echo ""

echo "🎯 Quick Access Test:"
echo "Frontend: http://$(minikube ip -p eduai-cluster 2>/dev/null || echo "N/A"):30007"
echo "Backend:  http://$(minikube ip -p eduai-cluster 2>/dev/null || echo "N/A"):30008"
echo ""
