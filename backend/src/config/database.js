const { Pool } = require('pg');
const redis = require('redis');
const { logger } = require('../utils/logger');

let pool;
let redisClient;

const connectDB = async () => {
  try {
    // PostgreSQL connection
    pool = new Pool({
      host: process.env.DB_HOST || 'eduai-postgres',
      port: process.env.DB_PORT || 5432,
      database: process.env.DB_NAME || 'eduai',
      user: process.env.DB_USER || 'postgres',
      password: process.env.DB_PASSWORD || 'postgres',
      max: 20,
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 2000,
    });

    // Test PostgreSQL connection
    await pool.query('SELECT NOW()');
    logger.info('PostgreSQL connected successfully');

    // Redis connection
    redisClient = redis.createClient({
      url: process.env.REDIS_URL || `redis://:${process.env.REDIS_PASSWORD || ''}@${process.env.REDIS_HOST || 'eduai-redis'}:${process.env.REDIS_PORT || 6379}`,
      socket: {
        reconnectStrategy: (retries) => {
          if (retries > 10) {
            logger.error('Redis: max reconnection attempts reached');
            return new Error('Max reconnection attempts reached');
          }
          return Math.min(retries * 100, 3000);
        },
      },
    });

    redisClient.on('error', (err) => {
      logger.error('Redis Client Error', err);
    });

    redisClient.on('connect', () => {
      logger.info('Redis connected successfully');
    });

    await redisClient.connect();
    logger.info('Database connections established');

  } catch (error) {
    logger.error('Database connection failed:', error);
    process.exit(1);
  }
};

const getDB = () => {
  if (!pool) {
    throw new Error('Database not initialized. Call connectDB() first.');
  }
  return pool;
};

const getRedis = () => {
  if (!redisClient) {
    throw new Error('Redis not initialized. Call connectDB() first.');
  }
  return redisClient;
};

const query = async (text, params) => {
  const start = Date.now();
  try {
    if (!pool) {
      logger.error('Database pool is undefined - connectDB() may not have been called');
      throw new Error('Database not initialized. Call connectDB() first.');
    }
    
    logger.debug('Executing query:', { text, params });
    const res = await pool.query(text, params);
    const duration = Date.now() - start;
    logger.debug('Query executed successfully', { text, duration, rows: res.rowCount });
    return res;
  } catch (error) {
    logger.error('Database query error', { 
      text, 
      params: params || 'none',
      error: error.message,
      stack: error.stack 
    });
    throw error;
  }
};

const getClient = async () => {
  const client = await pool.connect();
  const query = client.query;
  const release = client.release;
  
  return {
    query: async (text, params) => {
      const start = Date.now();
      try {
        const res = await query(text, params);
        const duration = Date.now() - start;
        logger.debug('Executed client query', { text, duration, rows: res.rowCount });
        return res;
      } catch (error) {
        logger.error('Client query error', { text, error: error.message });
        throw error;
      }
    },
    release
  };
};

module.exports = {
  connectDB,
  getDB,
  getRedis,
  query,
  getClient
};
