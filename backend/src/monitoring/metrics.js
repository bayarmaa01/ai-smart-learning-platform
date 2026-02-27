const client = require('prom-client');

const setupMetrics = (app) => {
  const register = new client.Registry();
  client.collectDefaultMetrics({ register });

  const httpRequestDuration = new client.Histogram({
    name: 'http_request_duration_seconds',
    help: 'Duration of HTTP requests in seconds',
    labelNames: ['method', 'route', 'status_code'],
    buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1, 2, 5],
    registers: [register],
  });

  const httpRequestTotal = new client.Counter({
    name: 'http_requests_total',
    help: 'Total number of HTTP requests',
    labelNames: ['method', 'route', 'status_code'],
    registers: [register],
  });

  const activeConnections = new client.Gauge({
    name: 'active_connections',
    help: 'Number of active connections',
    registers: [register],
  });

  app.use((req, res, next) => {
    const start = Date.now();
    activeConnections.inc();

    res.on('finish', () => {
      const duration = (Date.now() - start) / 1000;
      const route = req.route?.path || req.path;
      const labels = { method: req.method, route, status_code: res.statusCode };

      httpRequestDuration.observe(labels, duration);
      httpRequestTotal.inc(labels);
      activeConnections.dec();
    });

    next();
  });

  app.get('/metrics', async (req, res) => {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
  });

  return { httpRequestDuration, httpRequestTotal, activeConnections };
};

module.exports = { setupMetrics };
