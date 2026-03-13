#!/bin/bash

# Initialize database and fix startup issues
echo "🗄️ Initializing EduAI Database..."

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL to be ready..."
until docker compose exec postgres pg_isready -U postgres -d eduai_db; do
  echo "Waiting for postgres..."
  sleep 2
done

echo "✅ PostgreSQL is ready!"

# Check if database is initialized
echo "🔍 Checking database status..."
DB_CHECK=$(docker compose exec -T postgres psql -U postgres -d eduai_db -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null || echo "0")

if [ "$DB_CHECK" -eq "0" ]; then
    echo "📊 Database is empty, initializing..."
    
    # Initialize schema
    echo "📝 Creating database schema..."
    docker compose exec -T postgres psql -U postgres -d eduai_db < ./backend/src/db/schema.sql
    
    # Seed initial data
    echo "🌱 Seeding initial data..."
    cd backend && npm run db:seed
    
    echo "✅ Database initialized successfully!"
else
    echo "✅ Database already initialized"
fi

# Check if default tenant exists
echo "🏢 Checking default tenant..."
TENANT_CHECK=$(docker compose exec -T postgres psql -U postgres -d eduai_db -c "SELECT COUNT(*) FROM tenants WHERE slug = 'default';" 2>/dev/null || echo "0")

if [ "$TENANT_CHECK" -eq "0" ]; then
    echo "🏢 Creating default tenant..."
    docker compose exec -T postgres psql -U postgres -d eduai_db -c "
        INSERT INTO tenants (id, name, slug, domain, settings, subscription_plan, max_users, is_active)
        VALUES (
            '00000000-0000-0000-0000-000000000001',
            'Default Organization',
            'default',
            'localhost',
            '{\"theme\": \"light\", \"timezone\": \"UTC\"}',
            'pro',
            10000,
            TRUE
        );
    "
    echo "✅ Default tenant created!"
fi

# Restart backend to pick up changes
echo "🔄 Restarting backend service..."
docker compose restart backend

echo ""
echo "🎉 Database initialization complete!"
echo ""
echo "🌐 Platform URLs:"
echo "  📱 Frontend: http://localhost:3000"
echo "  🔧 Backend API: http://localhost:5001"
echo "  🤖 AI Service: http://localhost:8001"
echo ""
echo "🧪 Test registration:"
echo "curl -X POST http://localhost:5001/api/v1/auth/register \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"email\":\"test@example.com\",\"password\":\"password123\",\"firstName\":\"Test\",\"lastName\":\"User\"}'"
