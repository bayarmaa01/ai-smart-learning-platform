const { Pool } = require('pg');
const { logger } = require('../utils/logger');

let pool = null;

const initializePool = () => {
  if (!pool) {
    logger.info('Initializing PostgreSQL pool...');
    pool = new Pool({
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT) || 5432,
      database: process.env.DB_NAME || 'eduai',
      user: process.env.DB_USER || 'postgres',
      password: process.env.DB_PASSWORD || 'postgres',
      max: parseInt(process.env.DB_POOL_MAX) || 20,
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 10000,
      ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
    });

    pool.on('error', (err) => {
      logger.error('Unexpected PostgreSQL pool error:', err);
    });

    logger.info('PostgreSQL pool initialized successfully');
  }
  return pool;
};

const connectDB = async () => {
  try {
    // Initialize pool if not already done
    initializePool();
    
    const client = await pool.connect();
    const result = await client.query('SELECT NOW()');
    client.release();
    logger.info(`PostgreSQL connected: ${result.rows[0].now}`);
    return true;
  } catch (err) {
    logger.error('PostgreSQL connection failed:', err);
    throw err;
  }
};

const query = async (text, params) => {
  const start = Date.now();
  try {
    // Ensure pool is initialized before using it
    if (!pool) {
      logger.warn('Pool not initialized, initializing now...');
      initializePool();
    }
    
    logger.debug('Executing query:', { text, params });
    const result = await pool.query(text, params);
    const duration = Date.now() - start;
    
    if (duration > 1000) {
      logger.warn(`Slow query detected (${duration}ms): ${text}`);
    }
    
    logger.debug('Query completed successfully', { 
      text, 
      duration, 
      rows: result.rowCount 
    });
    
    return result;
  } catch (err) {
    logger.error('Database query error:', { 
      query: text, 
      params,
      error: err.message 
    });
    throw err;
  }
};

const getClient = async () => {
  if (!pool) {
    logger.warn('Pool not initialized in getClient(), initializing now...');
    initializePool();
  }
  return pool.connect();
};

const transaction = async (callback) => {
  if (!pool) {
    logger.warn('Pool not initialized in transaction(), initializing now...');
    initializePool();
  }
  
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await callback(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
};

module.exports = { connectDB, query, getClient, transaction };
