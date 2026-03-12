const fs = require('fs');
const path = require('path');
const { connectDB, query, getClient } = require('./connection');
const { logger } = require('../utils/logger');

class DatabaseInitializer {
  constructor() {
    this.schemaPath = path.join(__dirname, 'schema.sql');
  }

  async initialize() {
    try {
      logger.info('Starting database initialization...');
      
      // Read and execute schema
      await this.executeSchema();
      
      // Seed initial data
      await this.seedData();
      
      // Verify installation
      await this.verifyInstallation();
      
      logger.info('Database initialization completed successfully');
      return true;
    } catch (error) {
      logger.error('Database initialization failed:', error);
      throw error;
    }
  }

  async executeSchema() {
    try {
      logger.info('Executing database schema...');
      
      const schemaSQL = fs.readFileSync(this.schemaPath, 'utf8');
      
      // Split SQL into individual statements
      const statements = schemaSQL
        .split(';')
        .map(stmt => stmt.trim())
        .filter(stmt => stmt.length > 0 && !stmt.startsWith('--'));

      const client = await getClient();
      
      try {
        for (const statement of statements) {
          if (statement.trim()) {
            await client.query(statement);
          }
        }
        logger.info('Database schema executed successfully');
      } finally {
        client.release();
      }
    } catch (error) {
      logger.error('Failed to execute schema:', error);
      throw error;
    }
  }

  async seedData() {
    try {
      logger.info('Seeding initial data...');
      
      // Check if data already exists
      const existingTenant = await query('SELECT id FROM tenants WHERE slug = $1', ['eduai']);
      
      if (existingTenant.rows.length === 0) {
        // Insert default tenant
        await query(`
          INSERT INTO tenants (id, name, slug, subscription_plan, settings)
          VALUES ($1, $2, $3, $4, $5)
          ON CONFLICT (slug) DO NOTHING
        `, [
          '00000000-0000-0000-0000-000000000001',
          'EduAI Platform',
          'eduai',
          'enterprise',
          JSON.stringify({
            theme: 'default',
            features: {
              ai_chat: true,
              certificates: true,
              analytics: true
            }
          })
        ]);

        // Insert categories
        const categories = [
          ['Programming', 'programming', 'code'],
          ['Data Science', 'data-science', 'chart'],
          ['AI/ML', 'ai-ml', 'brain'],
          ['DevOps', 'devops', 'server'],
          ['Design', 'design', 'palette'],
          ['Business', 'business', 'briefcase'],
          ['Marketing', 'marketing', 'megaphone']
        ];

        for (const [name, slug, icon] of categories) {
          await query(`
            INSERT INTO categories (name, slug, icon)
            VALUES ($1, $2, $3)
            ON CONFLICT (slug) DO NOTHING
          `, [name, slug, icon]);
        }

        // Insert subscription plans
        const plans = [
          {
            name: 'Free',
            slug: 'free',
            price_monthly: 0,
            price_yearly: 0,
            features: JSON.stringify(["5 free courses", "Basic AI chat", "Community access"]),
            limits: JSON.stringify({ ai_messages_per_day: 10, courses: 5 })
          },
          {
            name: 'Pro',
            slug: 'pro',
            price_monthly: 29,
            price_yearly: 19,
            features: JSON.stringify(["Unlimited courses", "Unlimited AI chat", "Offline downloads", "Priority support"]),
            limits: JSON.stringify({ ai_messages_per_day: -1, courses: -1 })
          },
          {
            name: 'Enterprise',
            slug: 'enterprise',
            price_monthly: 99,
            price_yearly: 79,
            features: JSON.stringify(["Everything in Pro", "Team management", "Custom branding", "SSO", "API access"]),
            limits: JSON.stringify({ ai_messages_per_day: -1, courses: -1, team_members: -1 })
          }
        ];

        for (const plan of plans) {
          await query(`
            INSERT INTO subscription_plans (name, slug, price_monthly, price_yearly, features, limits)
            VALUES ($1, $2, $3, $4, $5, $6)
            ON CONFLICT (slug) DO NOTHING
          `, [plan.name, plan.slug, plan.price_monthly, plan.price_yearly, plan.features, plan.limits]);
        }

        // Create demo admin user
        const bcrypt = require('bcryptjs');
        const hashedPassword = await bcrypt.hash('Admin@1234', 12);
        
        await query(`
          INSERT INTO users (tenant_id, email, password_hash, first_name, last_name, role, is_email_verified, is_active)
          VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
          ON CONFLICT (tenant_id, email) DO NOTHING
        `, [
          '00000000-0000-0000-0000-000000000001',
          'admin@eduai.com',
          hashedPassword,
          'Admin',
          'User',
          'super_admin',
          true,
          true
        ]);

        // Create demo student user
        const studentPassword = await bcrypt.hash('Student@1234', 12);
        
        await query(`
          INSERT INTO users (tenant_id, email, password_hash, first_name, last_name, role, is_email_verified, is_active)
          VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
          ON CONFLICT (tenant_id, email) DO NOTHING
        `, [
          '00000000-0000-0000-0000-000000000001',
          'student@eduai.com',
          studentPassword,
          'Student',
          'User',
          'student',
          true,
          true
        ]);

        logger.info('Initial data seeded successfully');
      } else {
        logger.info('Initial data already exists, skipping seeding');
      }
    } catch (error) {
      logger.error('Failed to seed data:', error);
      throw error;
    }
  }

  async verifyInstallation() {
    try {
      logger.info('Verifying database installation...');
      
      // Check critical tables exist
      const tables = ['tenants', 'users', 'courses', 'categories', 'subscription_plans'];
      
      for (const table of tables) {
        const result = await query(`
          SELECT EXISTS (
            SELECT FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name = $1
          )
        `, [table]);
        
        if (!result.rows[0].exists) {
          throw new Error(`Table ${table} not found`);
        }
      }
      
      // Check indexes
      const indexResult = await query(`
        SELECT indexname FROM pg_indexes 
        WHERE schemaname = 'public' 
        AND tablename = 'users'
      `);
      
      logger.info(`Found ${indexResult.rows.length} indexes on users table`);
      
      // Verify default tenant exists
      const tenantResult = await query('SELECT id FROM tenants WHERE slug = $1', ['eduai']);
      if (tenantResult.rows.length === 0) {
        throw new Error('Default tenant not found');
      }
      
      logger.info('Database installation verified successfully');
      return true;
    } catch (error) {
      logger.error('Database verification failed:', error);
      throw error;
    }
  }

  async reset() {
    try {
      logger.warn('Resetting database...');
      
      // Drop all tables (except system tables)
      const tables = await query(`
        SELECT tablename FROM pg_tables 
        WHERE schemaname = 'public'
      `);
      
      for (const table of tables.rows) {
        await query(`DROP TABLE IF EXISTS "${table.tablename}" CASCADE`);
      }
      
      // Re-initialize
      await this.initialize();
      
      logger.info('Database reset completed');
      return true;
    } catch (error) {
      logger.error('Database reset failed:', error);
      throw error;
    }
  }

  async getStatus() {
    try {
      const status = {
        connected: false,
        tables: [],
        version: null,
        size: null
      };
      
      // Check connection
      const result = await query('SELECT NOW() as now, version() as version');
      status.connected = true;
      status.version = result.rows[0].version;
      
      // Get table list
      const tables = await query(`
        SELECT tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
        FROM pg_tables 
        WHERE schemaname = 'public'
        ORDER BY tablename
      `);
      
      status.tables = tables.rows;
      
      // Get total database size
      const sizeResult = await query('SELECT pg_size_pretty(pg_database_size(current_database())) as size');
      status.size = sizeResult.rows[0].size;
      
      return status;
    } catch (error) {
      logger.error('Failed to get database status:', error);
      return { connected: false, error: error.message };
    }
  }
}

// Export singleton instance
const dbInitializer = new DatabaseInitializer();

module.exports = {
  dbInitializer,
  initializeDatabase: () => dbInitializer.initialize(),
  resetDatabase: () => dbInitializer.reset(),
  getDatabaseStatus: () => dbInitializer.getStatus()
};

// CLI support
if (require.main === module) {
  const command = process.argv[2];
  
  switch (command) {
    case 'init':
      dbInitializer.initialize();
      break;
    case 'reset':
      dbInitializer.reset();
      break;
    case 'status':
      dbInitializer.getStatus().then(console.log);
      break;
    default:
      console.log('Usage: node init.js [init|reset|status]');
  }
}
