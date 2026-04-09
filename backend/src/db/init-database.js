const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');
const { logger } = require('../utils/logger');

// Database connection
const pool = new Pool({
  host: process.env.DB_HOST || 'postgres',
  port: parseInt(process.env.DB_PORT) || 5432,
  database: process.env.DB_NAME || 'eduai',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres123',
  ssl: false,
});

async function initializeDatabase() {
  try {
    logger.info('Starting database initialization...');
    
    // Check if tables exist
    const result = await pool.query(`
      SELECT COUNT(*) as count 
      FROM information_schema.tables 
      WHERE table_schema = 'public'
    `);
    
    const tableCount = parseInt(result.rows[0].count);
    
    if (tableCount > 0) {
      logger.info(`Database already has ${tableCount} tables, skipping initialization`);
      return;
    }
    
    // Read and execute schema
    const schemaPath = path.join(__dirname, 'schema.sql');
    const schema = fs.readFileSync(schemaPath, 'utf8');
    
    await pool.query(schema);
    logger.info('Database schema created successfully');
    
    // Create default user
    await createDefaultUser();
    
    logger.info('Database initialization completed successfully');
    
  } catch (error) {
    logger.error('Database initialization failed:', error);
    throw error;
  } finally {
    await pool.end();
  }
}

async function createDefaultUser() {
  const bcrypt = require('bcrypt');
  
  try {
    // Check if default user exists
    const existingUser = await pool.query(
      'SELECT id FROM users WHERE email = $1',
      ['test@test.com']
    );
    
    if (existingUser.rows.length > 0) {
      logger.info('Default user already exists');
      return;
    }
    
    // Hash password
    const hashedPassword = await bcrypt.hash('123456', 10);
    
    // Create default user
    await pool.query(`
      INSERT INTO users (email, password_hash, first_name, last_name, email_verified, is_active, created_at, updated_at)
      VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW())
    `, ['test@test.com', hashedPassword, 'Test', 'User', true, true]);
    
    logger.info('Default user created: test@test.com / 123456');
    
  } catch (error) {
    logger.error('Failed to create default user:', error);
    throw error;
  }
}

// Run initialization if called directly
if (require.main === module) {
  initializeDatabase()
    .then(() => {
      logger.info('Database initialization completed');
      process.exit(0);
    })
    .catch((error) => {
      logger.error('Database initialization failed:', error);
      process.exit(1);
    });
}

module.exports = { initializeDatabase, createDefaultUser };
