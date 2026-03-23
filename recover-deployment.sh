#!/bin/bash

set -e

echo "🚨 DEPLOYMENT RECOVERY SCRIPT"
echo "============================="
echo ""

echo "🔧 Cleaning up failed ArgoCD installation..."
kubectl delete namespace argocd --ignore-not-found=true --wait=false

echo "🔧 Cleaning up monitoring installation..."
helm uninstall monitoring -n monitoring --ignore-not-found
kubectl delete namespace monitoring --ignore-not-found=true --wait=false

echo "🔧 Waiting for cleanup to complete..."
sleep 10

echo "✅ Cleanup completed. Now run:"
echo "   ./deploy-full-platform.sh"
echo ""
echo "🎯 This will retry with the fixed configuration:" 
echo "   - ArgoCD core-only installation (no ApplicationSet)"
echo "   - Minimal monitoring stack (low resource usage)"
