#!/bin/bash

set -e

echo "🚨 DEPLOYMENT RECOVERY SCRIPT"
echo "============================="
echo ""

echo "🔧 Checking Minikube status..."
if ! minikube status -p eduai-cluster | grep -q "Running"; then
    echo "⚠️  Minikube is not running. Starting it first..."
    minikube start -p eduai-cluster
    echo "✅ Minikube started"
fi

echo "🔧 Setting kubectl context..."
kubectl config use-context eduai-cluster

echo "🔧 Cleaning up failed ArgoCD installation..."
kubectl delete namespace argocd --ignore-not-found=true --wait=false --grace-period=0 --force || true

echo "🔧 Cleaning up monitoring installation..."
helm uninstall monitoring -n monitoring --ignore-not-found || true
kubectl delete namespace monitoring --ignore-not-found=true --wait=false --grace-period=0 --force || true

echo "🔧 Cleaning up applications..."
kubectl delete namespace eduai --ignore-not-found=true --wait=false --grace-period=0 --force || true

echo "🔧 Waiting for cleanup to complete..."
sleep 15

echo "🔧 Removing stuck CRDs..."
kubectl delete crd applications.argoproj.io --ignore-not-found=true --wait=false || true
kubectl delete crd appprojects.argoproj.io --ignore-not-found=true --wait=false || true
kubectl delete crd applicationsets.argoproj.io --ignore-not-found=true --wait=false || true

echo "✅ Cleanup completed. Now run:"
echo "   ./deploy-full-platform.sh"
echo ""
echo "🎯 This will retry with fixed configuration:" 
echo "   - ArgoCD v2.8.4 with individual CRD installation"
echo "   - Minimal monitoring stack (low resource usage)"
echo "   - Clean namespace cleanup"
