#!/bin/bash

echo "🔍 DEBUGGING MINIKUBE STATUS"
echo "=========================="

echo ""
echo "Minikube status output:"
minikube status

echo ""
echo "Minikube status grep test:"
if minikube status | grep -q "Running"; then
    echo "✅ Found 'Running' in minikube status"
else
    echo "❌ No 'Running' found in minikube status"
fi

echo ""
echo "Current kubectl context:"
kubectl config current-context 2>/dev/null || echo "No context set"

echo ""
echo "Kubectl version:"
kubectl version --short 2>/dev/null || echo "kubectl version failed"

echo ""
echo "Minikube kubectl version:"
minikube kubectl -- version --short 2>/dev/null || echo "minikube kubectl version failed"
