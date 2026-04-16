const { createClient } = require('redis');
let logger;
try {
  ({ logger } = require('../utils/logger'));
} catch (e) {
  // Fallback logger for test environment
  logger = {
    error: () => {},
    info: () => {},
    warn: () => {},
    debug: () => {},
    http: () => {}
  };
}

let client;

const connectRedis = async () => {
  const redisHost = process.env.REDIS_HOST || 'redis';
  const redisPort = process.env.REDIS_PORT || '6379';
  const redisDb = process.env.REDIS_DB || '0';
  
  try {
    client = createClient({
      url: `redis://${redisHost}:${redisPort}/${redisDb}`,
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

    client.on('error', (err) => logger.error('Redis Client Error:', err));
    client.on('connect', () => logger.info('Redis connected'));
    client.on('reconnecting', () => logger.warn('Redis reconnecting...'));

    await client.connect();
    logger.info(`Redis connecting to: ${redisHost}:${redisPort}/${redisDb}`);
  } catch (err) {
    logger.error('Failed to initialize Redis client:', err);
    // Create a mock client for graceful degradation
    client = {
      get: async () => null,
      set: async () => {},
      del: async () => {},
      keys: async () => [],
      incr: async () => 0,
      expire: async () => {},
      setEx: async () => {},
      on: () => {},
      connect: async () => {},
      isReady: () => false
    };
    logger.warn('Redis disabled - running without cache');
  }
};

const getCache = async (key) => {
  try {
    if (!client || typeof client.get !== 'function') {
      return null;
    }
    const data = await client.get(key);
    return data ? JSON.parse(data) : null;
  } catch (err) {
    logger.error('Redis GET error:', err);
    return null;
  }
};

const setCache = async (key, value, ttlSeconds = 3600) => {
  try {
    if (!client || typeof client.setEx !== 'function') {
      logger.warn('Redis not available - cache disabled');
      return;
    }
    await client.setEx(key, ttlSeconds, JSON.stringify(value));
  } catch (err) {
    logger.error('Redis SET error:', err);
  }
};

const deleteCache = async (key) => {
  try {
    if (!client || typeof client.del !== 'function') {
      return;
    }
    await client.del(key);
  } catch (err) {
    logger.error('Redis DEL error:', err);
  }
};

const deleteCachePattern = async (pattern) => {
  try {
    if (!client || typeof client.keys !== 'function') {
      return;
    }
    const keys = await client.keys(pattern);
    if (keys.length > 0) {
      await client.del(keys);
    }
  } catch (err) {
    logger.error('Redis DEL pattern error:', err);
  }
};

const incrementCounter = async (key, ttlSeconds = 3600) => {
  try {
    if (!client || typeof client.incr !== 'function') {
      return 0;
    }
    const count = await client.incr(key);
    if (count === 1 && typeof client.expire === 'function') {
      await client.expire(key, ttlSeconds);
    }
    return count;
  } catch (err) {
    logger.error('Redis INCR error:', err);
    return 0;
  }
};

const getRedisClient = () => client;

module.exports = { connectRedis, getCache, setCache, deleteCache, deleteCachePattern, incrementCounter, getRedisClient };
