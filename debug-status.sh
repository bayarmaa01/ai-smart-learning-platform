#!/bin/bash

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "🔍 DEBUG STATUS"
echo "=============="

echo ""
echo "📦 Minikube Status:"
minikube status -p eduai-cluster

echo ""
echo "🔧 Kubectl Context:"
kubectl config current-context

echo ""
echo "📊 Nodes:"
kubectl get nodes

echo ""
echo "🌐 Namespaces:"
kubectl get namespaces

echo ""
echo "📦 Pods in eduai:"
kubectl get pods -n eduai

echo ""
echo "🌐 Services in eduai:"
kubectl get svc -n eduai

echo ""
echo "🔧 Minikube IP:"
minikube ip -p eduai-cluster

echo ""
echo "✅ Debug completed!"
