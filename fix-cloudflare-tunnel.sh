#!/bin/bash

set -e

echo "🌐 CLOUDFLARE TUNNEL FIX"
echo "========================"
echo ""

# Check if Minikube is running
if ! minikube status -p eduai-cluster 2>/dev/null | grep -q "Running"; then
    echo "❌ Minikube is not running. Starting it first..."
    minikube start -p eduai-cluster
    echo "✅ Minikube started"
fi

# Set context
kubectl config use-context eduai-cluster

# Get Minikube IP
MINIKUBE_IP=$(minikube ip -p eduai-cluster)
echo "🌐 Minikube IP: $MINIKUBE_IP"

echo ""
echo "🔧 Updating Cloudflare Tunnel configuration..."

# Create config directory
mkdir -p ~/.cloudflared

# Update tunnel config to use correct Minikube IP
cat > ~/.cloudflared/config.yml <<EOF
tunnel: dbea55ba-3659-4dd7-ac66-67f900defbfd
credentials-file: /home/bayarmaa/.cloudflared/dbea55ba-3659-4dd7-ac66-67f900defbfd.json

ingress:
  - hostname: ailearn.duckdns.org
    service: http://$MINIKUBE_IP:30007
  - service: http_status:404
EOF

echo "✅ Updated Cloudflare config to point to $MINIKUBE_IP:30007"

echo ""
echo "🔄 Restarting Cloudflare Tunnel..."

# Check if cloudflared service exists and restart
if command -v systemctl &> /dev/null; then
    if systemctl is-active --quiet cloudflared 2>/dev/null; then
        sudo systemctl restart cloudflared
        echo "✅ Cloudflare Tunnel restarted"
    else
        echo "⚠️  Cloudflare Tunnel service not running, starting it..."
        sudo systemctl start cloudflared || echo "❌ Failed to start Cloudflare Tunnel service"
    fi
else
    echo "⚠️  systemctl not available, please restart cloudflared manually"
fi

echo ""
echo "🧪 Testing connectivity..."

# Test local NodePort
echo "📡 Testing NodePort $MINIKUBE_IP:30007..."
if curl -s --max-time 5 "http://$MINIKUBE_IP:30007" > /dev/null; then
    echo "✅ NodePort is accessible"
else
    echo "❌ NodePort not accessible"
fi

# Test Cloudflare Tunnel
echo "🌐 Testing Cloudflare Tunnel..."
if curl -s --max-time 10 "https://ailearn.duckdns.org" > /dev/null; then
    echo "✅ Cloudflare Tunnel is working"
else
    echo "❌ Cloudflare Tunnel not working - check Cloudflare dashboard"
fi

echo ""
echo "📋 Current Configuration:"
echo "   NodePort: http://$MINIKUBE_IP:30007"
echo "   Tunnel:   https://ailearn.duckdns.org"
echo ""
echo "🔍 If still not working:"
echo "   1. Check Cloudflare Dashboard > Tunnels > eduai"
echo "   2. Verify tunnel is active and healthy"
echo "   3. Check DNS: ailearn.duckdns.org should point to Cloudflare"
echo "   4. Run: sudo journalctl -u cloudflared -f"
