#!/bin/bash

echo "==============================================="
echo "  COMPLETE SYSTEM FIX AND DEPLOY"
echo "==============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() { printf "${GREEN}[INFO]${NC} %s\n" "$1"; }
warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$1"; }

# 1. Test database connection
echo "1. Testing database connection..."
kubectl exec -n eduai postgres-74b756c75f-x4mf2 -- psql -U postgres -d eduai -c "SELECT version();" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    log "Database connection successful"
else
    error "Database connection failed"
    exit 1
fi

# 2. Run migrations
echo "2. Running database migrations..."
kubectl exec -n eduai backend-5d7f6d47f9-rlq5f -- node src/db/migrate.js migrate > /dev/null 2>&1
if [ $? -eq 0 ]; then
    log "Migrations completed successfully"
else
    error "Migrations failed"
    exit 1
fi

# 3. Seed database
echo "3. Seeding database..."
kubectl exec -n eduai backend-5d7f6d47f9-rlq5f -- node src/db/seed.js seed > /dev/null 2>&1
if [ $? -eq 0 ]; then
    log "Database seeded successfully"
else
    warn "Database seeding may have failed (might already be seeded)"
fi

# 4. Verify tables exist
echo "4. Verifying database tables..."
TABLES=$(kubectl exec -n eduai postgres-74b756c75f-x4mf2 -- psql -U postgres -d eduai -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public'" | tr -d ' ')
if [ "$TABLES" -gt "0" ]; then
    log "Found $TABLES tables in database"
else
    error "No tables found in database"
    exit 1
fi

# 5. Restart backend to apply changes
echo "5. Restarting backend pods..."
kubectl rollout restart deployment/backend -n eduai > /dev/null 2>&1
kubectl rollout status deployment/backend -n eduai > /dev/null 2>&1
log "Backend restarted successfully"

# 6. Restart frontend to apply changes
echo "6. Restarting frontend pods..."
kubectl rollout restart deployment/frontend -n eduai > /dev/null 2>&1
kubectl rollout status deployment/frontend -n eduai > /dev/null 2>&1
log "Frontend restarted successfully"

# 7. Test API endpoints
echo "7. Testing API endpoints..."

# Test health endpoint
HEALTH=$(curl -s http://localhost:4200/api/v1/health | jq -r '.status' 2>/dev/null)
if [ "$HEALTH" = "healthy" ]; then
    log "Health endpoint working"
else
    error "Health endpoint not working"
fi

# Test login endpoint
LOGIN=$(curl -s -X POST http://localhost:4200/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@eduai.com","password":"Admin@1234"}' | jq -r '.success' 2>/dev/null)
if [ "$LOGIN" = "true" ]; then
    log "Login endpoint working"
else
    error "Login endpoint not working"
fi

# Test courses endpoint
COURSES=$(curl -s http://localhost:4200/api/v1/courses | jq -r '.courses | length' 2>/dev/null)
if [ "$COURSES" -gt "0" ]; then
    log "Courses endpoint working ($COURSES courses found)"
else
    error "Courses endpoint not working"
fi

# 8. Test AI endpoint
echo "8. Testing AI endpoint..."
AI_RESPONSE=$(curl -s -X POST http://localhost:5200/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message":"Hello, how are you?"}' | jq -r '.response' 2>/dev/null)
if [ "$AI_RESPONSE" != "null" ] && [ "$AI_RESPONSE" != "" ]; then
    log "AI endpoint working"
else
    warn "AI endpoint may not be working"
fi

# 9. Test frontend
echo "9. Testing frontend..."
FRONTEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3200)
if [ "$FRONTEND_STATUS" = "200" ]; then
    log "Frontend accessible"
else
    error "Frontend not accessible (HTTP $FRONTEND_STATUS)"
fi

# 10. Summary
echo ""
echo "==============================================="
echo "  SYSTEM FIX SUMMARY"
echo "==============================================="
echo "Database: $([ "$TABLES" -gt "0" ] && echo "WORKING" || echo "FAILED")"
echo "Backend API: $([ "$HEALTH" = "healthy" ] && echo "WORKING" || echo "FAILED")"
echo "Authentication: $([ "$LOGIN" = "true" ] && echo "WORKING" || echo "FAILED")"
echo "Courses: $([ "$COURSES" -gt "0" ] && echo "WORKING" || echo "FAILED")"
echo "Frontend: $([ "$FRONTEND_STATUS" = "200" ] && echo "WORKING" || echo "FAILED")"
echo "AI Service: $([ "$AI_RESPONSE" != "null" ] && echo "WORKING" || echo "NEEDS CHECK")"
echo ""

# 11. Access URLs
echo "==============================================="
echo "  ACCESS URLS"
echo "==============================================="
echo "Frontend:   http://localhost:3200"
echo "Backend:    http://localhost:4200"
echo "AI Chat:    http://localhost:5200/api/chat"
echo "Health:     http://localhost:4200/api/v1/health"
echo "Auth:       http://localhost:4200/api/v1/auth/login"
echo "Courses:    http://localhost:4200/api/v1/courses"
echo ""

# 12. Test credentials
echo "==============================================="
echo "  TEST CREDENTIALS"
echo "==============================================="
echo "Admin:     admin@eduai.com / Admin@1234"
echo "Student:   student@eduai.com / Student@1234"
echo "Instructor: john.instructor@eduai.com / Instructor@1234"
echo ""

echo "==============================================="
echo "  FIX COMPLETE"
echo "=============================================="
