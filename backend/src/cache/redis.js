const { createClient } = require('redis');
const { logger } = require('../utils/logger');

let client;

const connectRedis = async () => {
  client = createClient({
    url: process.env.REDIS_URL || 'redis://localhost:6379',
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
};

const getCache = async (key) => {
  try {
    const data = await client.get(key);
    return data ? JSON.parse(data) : null;
  } catch (err) {
    logger.error('Redis GET error:', err);
    return null;
  }
};

const setCache = async (key, value, ttlSeconds = 3600) => {
  try {
    await client.setEx(key, ttlSeconds, JSON.stringify(value));
  } catch (err) {
    logger.error('Redis SET error:', err);
  }
};

const deleteCache = async (key) => {
  try {
    await client.del(key);
  } catch (err) {
    logger.error('Redis DEL error:', err);
  }
};

const deleteCachePattern = async (pattern) => {
  try {
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
    const count = await client.incr(key);
    if (count === 1) {
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
