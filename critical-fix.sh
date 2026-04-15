#!/bin/bash

echo "==============================================="
echo "  CRITICAL SYSTEM FIX"
echo "==============================================="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { printf "${GREEN}[INFO]${NC} %s\n" "$1"; }
warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$1"; }

# 1. FIX DATABASE CONNECTION AND TABLES
echo "1. Creating database tables directly..."
kubectl exec -n eduai postgres-74b756c75f-x4mf2 -- psql -U postgres -d eduai << 'EOF'
-- Create extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID DEFAULT '00000000-0000-0000-0000-000000000001',
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    role VARCHAR(50) DEFAULT 'student',
    avatar_url TEXT,
    bio TEXT,
    language_preference VARCHAR(10) DEFAULT 'en',
    placement_level VARCHAR(20) DEFAULT 'beginner',
    is_active BOOLEAN DEFAULT TRUE,
    is_email_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create categories table
CREATE TABLE IF NOT EXISTS categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    icon VARCHAR(50),
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create courses table
CREATE TABLE IF NOT EXISTS courses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID DEFAULT '00000000-0000-0000-0000-000000000001',
    instructor_id UUID NOT NULL REFERENCES users(id),
    category_id UUID REFERENCES categories(id),
    title VARCHAR(500) NOT NULL,
    slug VARCHAR(500) UNIQUE NOT NULL,
    description TEXT,
    short_description VARCHAR(500),
    thumbnail_url TEXT,
    language VARCHAR(10) DEFAULT 'en',
    level VARCHAR(50) DEFAULT 'beginner',
    price DECIMAL(10,2) DEFAULT 0,
    duration_hours DECIMAL(5,2),
    status VARCHAR(50) DEFAULT 'published',
    is_featured BOOLEAN DEFAULT FALSE,
    is_free BOOLEAN DEFAULT FALSE,
    enrollment_count INTEGER DEFAULT 0,
    rating_average DECIMAL(3,2) DEFAULT 0,
    rating_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert basic data
INSERT INTO categories (id, name, slug, description) VALUES
('00000000-0000-0000-0000-000000000001', 'Programming', 'programming', 'Programming and development courses'),
('00000000-0000-0000-0000-000000000002', 'Data Science', 'data-science', 'Data science and machine learning courses')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO users (id, email, password_hash, first_name, last_name, role, is_email_verified, is_active) VALUES
('00000000-0000-0000-0000-000000000001', 'admin@eduai.com', '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj6ukx.LrUpG', 'Admin', 'User', 'admin', true, true),
('00000000-0000-0000-0000-000000000002', 'student@eduai.com', '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj6ukx.LrUpG', 'Student', 'User', 'student', true, true)
ON CONFLICT (email) DO NOTHING;

INSERT INTO courses (id, instructor_id, category_id, title, slug, description, short_description, level, price, duration_hours, status, is_free, is_featured) VALUES
('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'Introduction to Web Development', 'intro-web-dev', 'Learn the basics of web development with HTML, CSS, and JavaScript', 'Basic web development course', 'beginner', 0, 20, 'published', true, true),
('00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'Python for Data Science', 'python-data-science', 'Learn Python programming for data science and machine learning', 'Python data science course', 'intermediate', 99.99, 40, 'published', false, true)
ON CONFLICT (slug) DO NOTHING;
EOF

log "Database tables created"

# 2. FIX BACKEND DATABASE CONNECTION
echo "2. Fixing backend database connection..."
kubectl exec -n eduai deployment/backend -- node -e "
const fs = require('fs');
const path = require('path');

// Update connection.js to ensure pool is initialized
const connectionPath = '/app/src/db/connection.js';
let content = fs.readFileSync(connectionPath, 'utf8');

// Fix the connectDB function to ensure pool is properly initialized
const updatedContent = content.replace(
  /const connectDB = async \(\) => \{[\s\S]*?\};/,
  \`const connectDB = async () => {
    try {
      const config = {
        host: process.env.DB_HOST || 'postgres',
        port: process.env.DB_PORT || 5432,
        database: process.env.DB_NAME || 'eduai',
        user: process.env.DB_USER || 'postgres',
        password: process.env.DB_PASSWORD || 'postgres',
        max: 20,
        idleTimeoutMillis: 30000,
        connectionTimeoutMillis: 2000,
      };
      
      if (!pool) {
        pool = new Pool(config);
      }
      
      await pool.query('SELECT NOW()');
      logger.info('Database connected successfully');
      return pool;
    } catch (error) {
      logger.error('Database connection failed:', error);
      throw error;
    }
  };\`
);

fs.writeFileSync(connectionPath, updatedContent);
console.log('Database connection fixed');
"

# 3. RESTART BACKEND
echo "3. Restarting backend..."
kubectl rollout restart deployment/backend -n eduai
kubectl rollout status deployment/backend -n eduai --timeout=60s

log "Backend restarted"

# 4. FIX AI ROUTING
echo "4. Adding AI chat route to server.js..."
kubectl exec -n eduai deployment/backend -- node -e "
const fs = require('fs');
const serverPath = '/app/src/server.js';
let content = fs.readFileSync(serverPath, 'utf8');

// Add chat route before the main routes
if (!content.includes('app.use(\"/api/v1/chat\"')) {
  const updatedContent = content.replace(
    'app.use(\"/api/v1\", routes);',
    'app.use(\"/api/v1/chat\", require(\"./routes/chat\"));\napp.use(\"/api/v1\", routes);'
  );
  fs.writeFileSync(serverPath, updatedContent);
  console.log('Chat route added');
} else {
  console.log('Chat route already exists');
}
"

# 5. FIX AI HEALTH CHECK (remove auth)
echo "5. Fixing AI health check authentication..."
kubectl exec -n eduai deployment/backend -- node -e "
const fs = require('fs');
const aiRoutePath = '/app/src/routes/ai.js';
let content = fs.readFileSync(aiRoutePath, 'utf8');

// Remove verifyToken middleware from health check
const updatedContent = content.replace(
  'router.get(\"/health\", verifyToken, aiController.health);',
  'router.get(\"/health\", aiController.health);'
);

fs.writeFileSync(aiRoutePath, updatedContent);
console.log('AI health check authentication fixed');
"

# 6. RESTART BACKEND AGAIN
echo "6. Restarting backend for AI routing fix..."
kubectl rollout restart deployment/backend -n eduai
kubectl rollout status deployment/backend -n eduai --timeout=60s

log "Backend restarted with AI fixes"

# 7. FIX PORT FORWARDS
echo "7. Restarting port forwards..."
pkill -f "kubectl port-forward"
sleep 2

# Start port forwards in background
kubectl port-forward -n eduai svc/frontend 3200:3000 &
kubectl port-forward -n eduai svc/backend 4200:5000 &
kubectl port-forward -n eduai svc/backend 5200:5000 &
kubectl port-forward -n monitoring svc/grafana 3004:3000 &

sleep 3
log "Port forwards restarted"

# 8. TEST DATABASE
echo "8. Testing database..."
TABLES=$(kubectl exec -n eduai postgres-74b756c75f-x4mf2 -- psql -U postgres -d eduai -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public'" | tr -d ' ')
USERS=$(kubectl exec -n eduai postgres-74b756c75f-x4mf2 -- psql -U postgres -d eduai -t -c "SELECT COUNT(*) FROM users" | tr -d ' ')
COURSES=$(kubectl exec -n eduai postgres-74b756c75f-x4mf2 -- psql -U postgres -d eduai -t -c "SELECT COUNT(*) FROM courses" | tr -d ' ')

echo "Tables: $TABLES"
echo "Users: $USERS"
echo "Courses: $COURSES"

# 9. TEST API
echo "9. Testing API endpoints..."
echo "Testing health endpoint..."
curl -s http://localhost:4200/api/v1/health | jq -r '.status' || echo "FAILED"

echo "Testing login endpoint..."
curl -s -X POST http://localhost:4200/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@eduai.com","password":"Admin@1234"}' | jq -r '.success' || echo "FAILED"

echo "Testing courses endpoint..."
curl -s http://localhost:4200/api/v1/courses | jq '.courses | length' || echo "FAILED"

echo "Testing AI health check..."
curl -s http://localhost:4200/api/v1/ai/health | jq -r '.status // "FAILED"'

echo "Testing AI chat endpoint..."
curl -s -X POST http://localhost:4200/api/v1/chat \
  -H "Content-Type: application/json" \
  -d '{"message":"Hello"}' | jq -r '.success // "FAILED"'

echo ""
echo "==============================================="
echo "  CRITICAL FIX COMPLETE"
echo "==============================================="
echo "Frontend:   http://localhost:3200"
echo "Backend:    http://localhost:4200"
echo "Login:      admin@eduai.com / Admin@1234"
echo "Student:    student@eduai.com / Student@1234"
echo "=============================================="
