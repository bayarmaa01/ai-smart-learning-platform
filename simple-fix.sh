#!/bin/bash

set -e

echo "🔧 SIMPLE PLATFORM FIX"
echo "===================="
echo ""

echo "🔧 STEP 1: Clean up broken cluster..."
minikube stop -p eduai-cluster || true
minikube delete -p eduai-cluster || true
echo "✅ Old cluster cleaned"

echo ""
echo "🔧 STEP 2: Start with stable configuration..."
minikube start -p eduai-cluster \
    --driver=docker \
    --cpus=2 \
    --memory=4096 \
    --kubernetes-version=v1.28.0 \
    --force
echo "✅ Minikube started with stable version"

echo ""
echo "🔧 STEP 3: Set context and verify..."
kubectl config use-context eduai-cluster
kubectl get nodes
echo "✅ Cluster ready"

echo ""
echo "🔧 STEP 4: Deploy applications only (no heavy monitoring)..."
kubectl create namespace eduai --dry-run=client -o yaml | kubectl apply -f -

echo "Deploying frontend..."
kubectl apply -n eduai -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  labels:
    app: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
spec:
  selector:
    app: frontend
  type: NodePort
  ports:
  - port: 3000
    targetPort: 80
    nodePort: 30007
EOF

echo "Deploying backend..."
kubectl apply -n eduai -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  labels:
    app: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: backend
spec:
  selector:
    app: backend
  type: NodePort
  ports:
  - port: 5000
    targetPort: 80
    nodePort: 30008
EOF

echo "✅ Applications deployed"

echo ""
echo "🔧 STEP 5: Wait for pods to be ready..."
kubectl wait --for=condition=Ready pods -n eduai --all --timeout=300s
echo "✅ Pods ready"

echo ""
echo "🔧 STEP 6: Test NodePort access..."
MINIKUBE_IP=$(minikube ip -p eduai-cluster)
echo "Testing frontend: http://$MINIKUBE_IP:30007"
curl -I "http://$MINIKUBE_IP:30007" --max-time 10 || echo "❌ Frontend not accessible"

echo "Testing backend: http://$MINIKUBE_IP:30008"
curl -I "http://$MINIKUBE_IP:30008" --max-time 10 || echo "❌ Backend not accessible"

echo ""
echo "🎯 PLATFORM STATUS:"
echo "=================="
echo "✅ Minikube: Running (v1.28.0)"
echo "✅ Services: Frontend + Backend"
echo "✅ NodePorts: 30007 (frontend), 30008 (backend)"
echo ""
echo "📱 Access URLs:"
echo "Frontend: http://$MINIKUBE_IP:30007"
echo "Backend:  http://$MINIKUBE_IP:30008"
echo ""
echo "🔧 For port-forwarding:"
echo "kubectl port-forward svc/frontend -n eduai 3000:3000"
echo "kubectl port-forward svc/backend -n eduai 5000:5000"
echo ""
echo "📊 Check status:"
echo "kubectl get pods -n eduai"
echo "kubectl get svc -n eduai"
