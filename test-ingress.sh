#!/bin/bash

set -e

echo "🌐 INGRESS TESTING"
echo "=================="
echo ""

# Get Minikube IP from service status
MINIKUBE_IP="192.168.58.2"
echo "🌐 Testing with Minikube IP: $MINIKUBE_IP"
echo ""

echo "📡 Testing Frontend via Ingress:"
curl -H "Host: ailearn.duckdns.org" "http://$MINIKUBE_IP/" -I --max-time 10 || echo "❌ Frontend test failed"
echo ""

echo "📡 Testing Backend API via Ingress:"
curl -H "Host: ailearn.duckdns.org" "http://$MINIKUBE_IP/api/" -I --max-time 10 || echo "❌ Backend test failed"
echo ""

echo "📡 Testing Direct NodePort (Frontend):"
curl "http://$MINIKUBE_IP:30007" -I --max-time 10 || echo "❌ Frontend NodePort failed"
echo ""

echo "📡 Testing Direct NodePort (Backend):"
curl "http://$MINIKUBE_IP:30008" -I --max-time 10 || echo "❌ Backend NodePort failed"
echo ""

echo "📊 Ingress Status:"
kubectl get ingress -n eduai
echo ""

echo "🔧 Ingress Details:"
kubectl describe ingress eduai-ingress -n eduai | grep -A 20 "Rules:"
echo ""

echo "🌐 External Test (Cloudflare Tunnel):"
curl "https://ailearn.duckdns.org" -I --max-time 10 || echo "❌ Cloudflare Tunnel test failed"
echo ""

echo "✅ Ingress testing complete!"
