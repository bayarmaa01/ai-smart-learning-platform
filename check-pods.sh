#!/bin/bash

set -e

echo "🔍 POD STATUS CHECK"
echo "=================="
echo ""

echo "📊 Current Pod Status:"
kubectl get pods -n eduai
echo ""

echo "🔧 Pod Details:"
kubectl describe pods -n eduai
echo ""

echo "📋 Service Status:"
kubectl get svc -n eduai
echo ""

echo "🔧 Events in eduai namespace:"
kubectl get events -n eduai --sort-by='.lastTimestamp'
echo ""

echo "🔧 Node Status:"
kubectl get nodes -o wide
echo ""

echo "🔧 System Events:"
kubectl get events --sort-by='.lastTimestamp' | tail -10
echo ""

echo "🎯 Troubleshooting Commands:"
echo "=========================="
echo "# Check pod logs:"
echo "kubectl logs -n eduai deployment/frontend"
echo "kubectl logs -n eduai deployment/backend"
echo ""
echo "# Describe specific pod:"
echo "kubectl describe pod -n eduai <pod-name>"
echo ""
echo "# Check resources:"
echo "kubectl top nodes"
echo "kubectl top pods -n eduai"
echo ""
echo "# Restart deployments:"
echo "kubectl rollout restart deployment/frontend -n eduai"
echo "kubectl rollout restart deployment/backend -n eduai"
