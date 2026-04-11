#!/bin/bash

# OpenClaw Ollama Migration Script
# Fixes Gemini quota issues by switching to Ollama

echo "=== OpenClaw Ollama Migration Script ==="

# Backup current config
echo "1. Backing up current configuration..."
cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.backup-$(date +%Y%m%d-%H%M%S)

# Validate Ollama connectivity
echo "2. Validating Ollama connectivity..."
if ! curl -s http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    echo "ERROR: Ollama not accessible at http://127.0.0.1:11434"
    echo "Please ensure Ollama is running: ollama serve"
    exit 1
fi

echo "   Ollama is accessible"

# Check if required models are available
echo "3. Checking Ollama models..."
MODELS=$(curl -s http://127.0.0.1:11434/api/tags | jq -r '.models[].name' 2>/dev/null || echo "")

if ! echo "$MODELS" | grep -q "gemma4:31b-cloud"; then
    echo "WARNING: gemma4:31b-cloud not found, pulling..."
    ollama pull gemma4:31b-cloud
fi

if ! echo "$MODELS" | grep -q "gemma3"; then
    echo "WARNING: gemma3 not found, pulling..."
    ollama pull gemma3
fi

# Create new configuration
echo "4. Creating Ollama-only configuration..."
cat > ~/.openclaw/openclaw.json << 'EOF'
{
  "workspace": "~/.openclaw/workspace",
  "model": "ollama/gemma4:31b-cloud",
  "fallbackModels": ["ollama/gemma3"],
  "modelProviders": {
    "ollama": {
      "baseUrl": "http://127.0.0.1:11434",
      "enabled": true,
      "priority": 1,
      "timeout": 30000,
      "retries": 3,
      "retryDelay": 5000
    },
    "google": {
      "enabled": false,
      "priority": 999
    },
    "openai": {
      "enabled": false,
      "priority": 999
    },
    "anthropic": {
      "enabled": false,
      "priority": 999
    }
  },
  "gateway": {
    "mode": "local",
    "port": 18789,
    "bind": "127.0.0.1",
    "auth": {
      "type": "token"
    }
  },
  "skills": {
    "nodeManager": "npm"
  },
  "channels": {
    "whatsapp": {
      "enabled": true,
      "dmPolicy": "allowlist",
      "allowFrom": ["+917658055233"],
      "personalPhone": true
    }
  },
  "webSearch": {
    "provider": "ollama",
    "enabled": true
  },
  "performance": {
    "lowLatency": true,
    "localInference": true,
    "cacheEnabled": true,
    "batchRequests": false
  },
  "reliability": {
    "autoRestart": true,
    "healthCheckInterval": 30000,
    "maxRetries": 3,
    "fallbackEnabled": true
  },
  "security": {
    "disableExternalAPIs": true,
    "localOnly": true,
    "noApiQuota": true
  }
}
EOF

echo "5. Configuration updated"

# Restart OpenClaw services
echo "6. Restarting OpenClaw services..."
pkill -f openclaw || true
sleep 2

# Start gateway service
echo "7. Starting OpenClaw gateway..."
openclaw gateway --daemon --port 18789 --bind 127.0.0.1

# Wait for service to start
sleep 3

# Verify configuration
echo "8. Verifying new configuration..."
echo "Current model:"
openclaw config get model 2>/dev/null || echo "   Configuration applied"

# Test Ollama model
echo "9. Testing Ollama model..."
curl -s -X POST http://127.0.0.1:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemma4:31b-cloud",
    "prompt": "Hello, respond with OK",
    "stream": false
  }' | jq -r '.response' | head -c 20

echo ""
echo "=== Migration Complete ==="
echo ""
echo "Next steps:"
echo "1. Test with: openclaw tui - ws://127.0.0.1:18789 - agent main - session main"
echo "2. Verify no more Gemini quota errors"
echo "3. Check dashboard: http://127.0.0.1:18789"
echo ""
echo "If issues occur, restore backup:"
echo "cp ~/.openclaw/openclaw.json.backup-* ~/.openclaw/openclaw.json"
