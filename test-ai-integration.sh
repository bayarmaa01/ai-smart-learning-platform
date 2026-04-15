#!/bin/bash

echo "==============================================="
echo "  AI INTEGRATION TEST"
echo "==============================================="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { printf "${GREEN}[INFO]${NC} %s\n" "$1"; }
warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$1"; }

# 1. Test AI health check
echo "1. Testing AI health check..."
HEALTH_RESPONSE=$(curl -s http://localhost:4200/api/v1/ai/health)
HEALTH_STATUS=$(echo "$HEALTH_RESPONSE" | jq -r '.status' 2>/dev/null)

if [ "$HEALTH_STATUS" = "ok" ]; then
    log "AI health check passed"
    echo "  Status: $(echo "$HEALTH_RESPONSE" | jq -r '.status')"
    echo "  Model: $(echo "$HEALTH_RESPONSE" | jq -r '.model')"
    echo "  Available: $(echo "$HEALTH_RESPONSE" | jq -r '.available')"
else
    error "AI health check failed"
    echo "  Response: $HEALTH_RESPONSE"
fi

# 2. Test basic chat endpoint
echo -e "\n2. Testing chat endpoint..."
CHAT_RESPONSE=$(curl -s -X POST http://localhost:4200/api/v1/chat \
  -H "Content-Type: application/json" \
  -d '{"message":"Hello AI"}')

CHAT_SUCCESS=$(echo "$CHAT_RESPONSE" | jq -r '.success' 2>/dev/null)
CHAT_REPLY=$(echo "$CHAT_RESPONSE" | jq -r '.reply' 2>/dev/null)

if [ "$CHAT_SUCCESS" = "true" ] && [ "$CHAT_REPLY" != "null" ]; then
    log "Chat endpoint working"
    echo "  Reply: ${CHAT_REPLY:0:100}..."
else
    error "Chat endpoint failed"
    echo "  Response: $CHAT_RESPONSE"
fi

# 3. Test chat with longer message
echo -e "\n3. Testing chat with longer message..."
LONG_RESPONSE=$(curl -s -X POST http://localhost:4200/api/v1/chat \
  -H "Content-Type: application/json" \
  -d '{"message":"Can you explain the basics of machine learning in simple terms?"}')

LONG_SUCCESS=$(echo "$LONG_RESPONSE" | jq -r '.success' 2>/dev/null)
LONG_REPLY=$(echo "$LONG_RESPONSE" | jq -r '.reply' 2>/dev/null)

if [ "$LONG_SUCCESS" = "true" ] && [ "$LONG_REPLY" != "null" ]; then
    log "Long message test passed"
    echo "  Reply length: ${#LONG_REPLY} characters"
else
    error "Long message test failed"
    echo "  Response: $LONG_RESPONSE"
fi

# 4. Test error handling (empty message)
echo -e "\n4. Testing error handling..."
ERROR_RESPONSE=$(curl -s -X POST http://localhost:4200/api/v1/chat \
  -H "Content-Type: application/json" \
  -d '{"message":""}')

ERROR_STATUS=$(echo "$ERROR_RESPONSE" | jq -r '.success' 2>/dev/null)

if [ "$ERROR_STATUS" = "false" ]; then
    log "Error handling working correctly"
else
    warn "Error handling may need attention"
fi

# 5. Test rate limiting (multiple requests)
echo -e "\n5. Testing rate limiting..."
for i in {1..5}; do
    RATE_RESPONSE=$(curl -s -X POST http://localhost:4200/api/v1/chat \
      -H "Content-Type: application/json" \
      -d '{"message":"Test message '$i'"}' &
    )
done

wait
log "Rate limiting test completed"

# 6. Check backend logs for AI requests
echo -e "\n6. Checking backend AI logs..."
kubectl logs -n eduai deployment/backend --tail=20 | grep -i "ai\|ollama" || warn "No AI logs found"

# 7. Summary
echo -e "\n==============================================="
echo "  AI INTEGRATION TEST SUMMARY"
echo "==============================================="
echo "Health Check: $([ "$HEALTH_STATUS" = "ok" ] && echo "PASS" || echo "FAIL")"
echo "Chat Endpoint: $([ "$CHAT_SUCCESS" = "true" ] && echo "PASS" || echo "FAIL")"
echo "Long Messages: $([ "$LONG_SUCCESS" = "true" ] && echo "PASS" || echo "FAIL")"
echo "Error Handling: $([ "$ERROR_STATUS" = "false" ] && echo "PASS" || echo "NEEDS CHECK")"

echo -e "\n==============================================="
echo "  TEST URLS"
echo "==============================================="
echo "Health:     http://localhost:4200/api/v1/ai/health"
echo "Chat:       curl -X POST http://localhost:4200/api/v1/chat -H \"Content-Type: application/json\" -d '{\"message\":\"Hello AI\"}'"
echo ""

echo "==============================================="
echo "  AI INTEGRATION TEST COMPLETE"
echo "=============================================="
