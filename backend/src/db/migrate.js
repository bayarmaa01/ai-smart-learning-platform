const fs = require('fs');
const path = require('path');
const { query, getClient } = require('./connection');
const { logger } = require('../utils/logger');

class DatabaseMigrator {
  constructor() {
    this.migrationsPath = path.join(__dirname, 'migrations');
    this.migrationsTable = 'schema_migrations';
  }

  async initialize() {
    try {
      // Create migrations table if it doesn't exist
      await query(`
        CREATE TABLE IF NOT EXISTS ${this.migrationsTable} (
          id SERIAL PRIMARY KEY,
          filename VARCHAR(255) NOT NULL UNIQUE,
          executed_at TIMESTAMPTZ DEFAULT NOW()
        )
      `);
      
      // Create migrations directory if it doesn't exist
      if (!fs.existsSync(this.migrationsPath)) {
        fs.mkdirSync(this.migrationsPath, { recursive: true });
      }
      
      logger.info('Database migrator initialized');
    } catch (error) {
      logger.error('Failed to initialize migrator:', error);
      throw error;
    }
  }

  async createMigration(name, description) {
    try {
      const timestamp = new Date().toISOString().replace(/[-:T]/g, '').split('.')[0];
      const filename = `${timestamp}_${name}.sql`;
      const filepath = path.join(this.migrationsPath, filename);
      
      const template = `-- Migration: ${description}
-- Created: ${new Date().toISOString()}
-- Filename: ${filename}

-- Add your migration SQL here
-- Example:
-- ALTER TABLE users ADD COLUMN new_column VARCHAR(255);
-- CREATE INDEX idx_users_new_column ON users(new_column);

-- Rollback SQL (if needed)
-- Example:
-- ALTER TABLE users DROP COLUMN new_column;
`;
      
      fs.writeFileSync(filepath, template);
      logger.info(`Created migration: ${filename}`);
      return filename;
    } catch (error) {
      logger.error('Failed to create migration:', error);
      throw error;
    }
  }

  async getPendingMigrations() {
    try {
      // Get all migration files
      const migrationFiles = fs.readdirSync(this.migrationsPath)
        .filter(file => file.endsWith('.sql'))
        .sort();
      
      // Get executed migrations
      const executedResult = await query(`SELECT filename FROM ${this.migrationsTable}`);
      const executedFiles = executedResult.rows.map(row => row.filename);
      
      // Filter pending migrations
      const pendingMigrations = migrationFiles.filter(file => !executedFiles.includes(file));
      
      return pendingMigrations;
    } catch (error) {
      logger.error('Failed to get pending migrations:', error);
      throw error;
    }
  }

  async executeMigration(filename) {
    try {
      const filepath = path.join(this.migrationsPath, filename);
      const migrationSQL = fs.readFileSync(filepath, 'utf8');
      
      logger.info(`Executing migration: ${filename}`);
      
      const client = await getClient();
      
      try {
        await client.query('BEGIN');
        
        // Execute migration
        await client.query(migrationSQL);
        
        // Record migration
        await client.query(`
          INSERT INTO ${this.migrationsTable} (filename)
          VALUES ($1)
        `, [filename]);
        
        await client.query('COMMIT');
        
        logger.info(`Migration executed successfully: ${filename}`);
        return true;
      } catch (error) {
        await client.query('ROLLBACK');
        logger.error(`Migration failed: ${filename}`, error);
        throw error;
      } finally {
        client.release();
      }
    } catch (error) {
      logger.error('Failed to execute migration:', error);
      throw error;
    }
  }

  async migrate() {
    try {
      await this.initialize();
      
      const pendingMigrations = await this.getPendingMigrations();
      
      if (pendingMigrations.length === 0) {
        logger.info('No pending migrations');
        return { success: true, migrations: [] };
      }
      
      logger.info(`Found ${pendingMigrations.length} pending migrations`);
      
      const executedMigrations = [];
      
      for (const migration of pendingMigrations) {
        await this.executeMigration(migration);
        executedMigrations.push(migration);
      }
      
      logger.info(`Migrations completed: ${executedMigrations.length}`);
      return { success: true, migrations: executedMigrations };
    } catch (error) {
      logger.error('Migration failed:', error);
      throw error;
    }
  }

  async rollback(steps = 1) {
    try {
      // Get last executed migrations
      const result = await query(`
        SELECT filename FROM ${this.migrationsTable}
        ORDER BY executed_at DESC
        LIMIT $1
      `, [steps]);
      
      if (result.rows.length === 0) {
        logger.info('No migrations to rollback');
        return { success: true, rolledBack: [] };
      }
      
      const rolledBack = [];
      
      for (const row of result.rows) {
        const filename = row.filename;
        const filepath = path.join(this.migrationsPath, filename);
        
        if (!fs.existsSync(filepath)) {
          logger.warn(`Migration file not found: ${filename}`);
          continue;
        }
        
        // Extract rollback SQL from migration file
        const migrationSQL = fs.readFileSync(filepath, 'utf8');
        const rollbackMatch = migrationSQL.match(/-- Rollback SQL[^-]*\n([\s\S]*?)(?=\n--|\n$|$)/);
        
        if (rollbackMatch && rollbackMatch[1].trim()) {
          const rollbackSQL = rollbackMatch[1].trim();
          
          const client = await getClient();
          
          try {
            await client.query('BEGIN');
            await client.query(rollbackSQL);
            await client.query(`DELETE FROM ${this.migrationsTable} WHERE filename = $1`, [filename]);
            await client.query('COMMIT');
            
            logger.info(`Rolled back migration: ${filename}`);
            rolledBack.push(filename);
          } catch (error) {
            await client.query('ROLLBACK');
            logger.error(`Rollback failed for: ${filename}`, error);
            throw error;
          } finally {
            client.release();
          }
        } else {
          logger.warn(`No rollback SQL found for: ${filename}`);
        }
      }
      
      logger.info(`Rollback completed: ${rolledBack.length} migrations`);
      return { success: true, rolledBack };
    } catch (error) {
      logger.error('Rollback failed:', error);
      throw error;
    }
  }

  async getStatus() {
    try {
      const pendingMigrations = await this.getPendingMigrations();
      
      const executedResult = await query(`
        SELECT filename, executed_at FROM ${this.migrationsTable}
        ORDER BY executed_at DESC
        LIMIT 10
      `);
      
      return {
        pending: pendingMigrations.length,
        pendingFiles: pendingMigrations,
        lastExecuted: executedResult.rows[0] || null,
        recentExecuted: executedResult.rows
      };
    } catch (error) {
      logger.error('Failed to get migration status:', error);
      throw error;
    }
  }
}

// Export singleton instance
const migrator = new DatabaseMigrator();

module.exports = {
  migrator,
  runMigrations: () => migrator.migrate(),
  rollbackMigrations: (steps) => migrator.rollback(steps),
  createMigration: (name, description) => migrator.createMigration(name, description),
  getMigrationStatus: () => migrator.getStatus()
};

// CLI support
if (require.main === module) {
  const command = process.argv[2];
  const param = process.argv[3];
  
  switch (command) {
    case 'migrate':
      migrator.migrate();
      break;
    case 'rollback':
      migrator.rollback(parseInt(param) || 1);
      break;
    case 'create':
      const name = param || 'new_migration';
      migrator.createMigration(name, 'Auto-generated migration');
      break;
    case 'status':
      migrator.getStatus().then(console.log);
      break;
    default:
      console.log('Usage: node migrate.js [migrate|rollback|create|status] [param]');
  }
}
