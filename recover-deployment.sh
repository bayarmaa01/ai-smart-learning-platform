#!/bin/bash

set -e

echo "🚨 DEPLOYMENT RECOVERY SCRIPT"
echo "============================="
echo ""

echo "🔧 Cleaning up failed ArgoCD installation..."
kubectl delete namespace argocd --ignore-not-found=true --wait=false --grace-period=0 --force

echo "🔧 Cleaning up monitoring installation..."
helm uninstall monitoring -n monitoring --ignore-not-found
kubectl delete namespace monitoring --ignore-not-found=true --wait=false --grace-period=0 --force

echo "🔧 Cleaning up applications..."
kubectl delete namespace eduai --ignore-not-found=true --wait=false --grace-period=0 --force

echo "🔧 Waiting for cleanup to complete..."
sleep 15

echo "🔧 Removing stuck CRDs..."
kubectl delete crd applications.argoproj.io --ignore-not-found=true --wait=false
kubectl delete crd appprojects.argoproj.io --ignore-not-found=true --wait=false
kubectl delete crd applicationsets.argoproj.io --ignore-not-found=true --wait=false

echo "✅ Cleanup completed. Now run:"
echo "   ./deploy-full-platform.sh"
echo ""
echo "🎯 This will retry with fixed configuration:" 
echo "   - ArgoCD v2.8.4 with individual CRD installation"
echo "   - Minimal monitoring stack (low resource usage)"
echo "   - Clean namespace cleanup"
