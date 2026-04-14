#!/bin/bash

echo "==============================================="
echo "  QUICK DATABASE FIX"
echo "==============================================="

# Copy the SQL file to the postgres pod
echo "1. Copying SQL file to postgres pod..."
kubectl cp fix-database.sql eduai/postgres-74b756c75f-5jcqb:/tmp/fix-database.sql

# Execute the SQL
echo "2. Executing SQL schema..."
kubectl exec -n eduai postgres-74b756c75f-5jcqb -- psql -U postgres -d eduai -f /tmp/fix-database.sql

# Create users with hashed passwords
echo "3. Creating users..."
kubectl exec -n eduai postgres-74b756c75f-5jcqb -- psql -U postgres -d eduai -c "
INSERT INTO users (tenant_id, email, password_hash, first_name, last_name, role, is_email_verified, is_active) VALUES
    ('00000000-0000-0000-0000-000000000001', 'admin@eduai.com', '\$2a\$12\$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj6ukx.LFvOe', 'Admin', 'User', 'super_admin', true, true),
    ('00000000-0000-0000-0000-000000000001', 'student@eduai.com', '\$2a\$12\$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj6ukx.LFvOe', 'Student', 'User', 'student', true, true)
ON CONFLICT (tenant_id, email) DO NOTHING;
"

# Verify tables
echo "4. Verifying tables were created..."
kubectl exec -n eduai postgres-74b756c75f-5jcqb -- psql -U postgres -d eduai -c "\dt"

# Test backend
echo "5. Testing backend health..."
kubectl exec -n eduai backend-5d7f6d47f9-84q28 -- curl -f http://localhost:5000/api/v1/health

echo ""
echo "==============================================="
echo "  FIX COMPLETE"
echo "==============================================="
echo ""
echo "Login credentials:"
echo "Admin:  admin@eduai.com / Admin@1234"
echo "Student: student@eduai.com / Student@1234"
echo ""
echo "Access URLs:"
echo "Frontend: http://localhost:3200"
echo "Backend:  http://localhost:4200"
