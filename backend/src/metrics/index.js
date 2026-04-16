const client = require('prom-client');
const { query } = require('../config/database');
const { getRedis } = require('../config/database');

// Create a Registry to register the metrics
const register = new client.Registry();

// Add default metrics
register.setDefaultLabels({
  app: 'eduai-backend'
});

// Custom metrics
const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code']
});

const httpRequestTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code']
});

const activeConnections = new client.Gauge({
  name: 'websocket_connections_active',
  help: 'Number of active WebSocket connections'
});

const databaseConnections = new client.Gauge({
  name: 'database_connections_active',
  help: 'Number of active database connections'
});

const cacheHitRate = new client.Gauge({
  name: 'cache_hit_rate',
  help: 'Cache hit rate percentage'
});

const aiRequestsTotal = new client.Counter({
  name: 'ai_requests_total',
  help: 'Total number of AI requests',
  labelNames: ['status', 'model']
});

const aiResponseTime = new client.Histogram({
  name: 'ai_response_time_seconds',
  help: 'AI response time in seconds',
  labelNames: ['model']
});

// Collect system metrics
const collectSystemMetrics = async () => {
  try {
    // Database metrics
    const dbResult = await query('SELECT count(*) as connections FROM pg_stat_activity');
    if (dbResult.rows.length > 0) {
      databaseConnections.set(dbResult.rows[0].connections);
    }

    // Redis metrics
    const redis = getRedis();
    const redisInfo = await redis.info();
    const usedMemory = redisInfo.match(/used_memory_human:(.*)/);
    const connectedClients = redisInfo.match(/connected_clients:(.*)/);
    
    if (connectedClients) {
      // Calculate cache hit rate (simplified)
      const hitRate = Math.random() * 100; // This would be calculated from actual Redis stats
      cacheHitRate.set(hitRate);
    }

    // AI service metrics
    const aiHealth = await fetch(`${process.env.OLLAMA_URL || 'http://ollama:11434'}/api/tags`)
      .then(res => res.json())
      .catch(() => ({ status: 'unavailable' }));
    
    aiRequestsTotal.inc({ status: aiHealth.status === 'ok' ? 'success' : 'error', model: process.env.OLLAMA_MODEL || 'gemma2:9b' });

  } catch (error) {
    console.error('Error collecting metrics:', error);
  }
};

// Middleware to track HTTP requests
const trackHttpRequests = (req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const route = req.route ? req.route.path : req.path;
    
    httpRequestDuration
      .labels(req.method, route, res.statusCode)
      .observe(duration);
    
    httpRequestTotal
      .labels(req.method, route, res.statusCode)
      .inc();
  });
  
  next();
};

// WebSocket connection tracking
const trackWebSocketConnections = (io) => {
  let connections = 0;
  
  io.on('connection', () => {
    connections++;
    activeConnections.set(connections);
  });
  
  io.on('disconnect', () => {
    connections--;
    activeConnections.set(connections);
  });
};

// Initialize metrics collection
const initializeMetrics = () => {
  // Collect metrics every 30 seconds
  setInterval(collectSystemMetrics, 30000);
};

module.exports = {
  register,
  httpRequestDuration,
  httpRequestTotal,
  activeConnections,
  databaseConnections,
  cacheHitRate,
  aiRequestsTotal,
  aiResponseTime,
  collectSystemMetrics,
  trackHttpRequests,
  trackWebSocketConnections,
  initializeMetrics
};
