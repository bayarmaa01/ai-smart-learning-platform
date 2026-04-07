const rateLimit = require('express-rate-limit');
const { logger } = require('../utils/logger');

/**
 * Rate Limiter Middleware for AI Endpoints
 * Limits AI requests to prevent abuse
 */
const rateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 30, // Limit each IP to 30 requests per windowMs
  message: {
    success: false,
    error: 'Too many AI requests. Please try again later.',
    retryAfter: '15 minutes'
  },
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    logger.warn('Rate limit exceeded for AI endpoint', {
      ip: req.ip,
      path: req.path,
      userAgent: req.get('User-Agent')
    });
    
    res.status(429).json({
      success: false,
      error: 'Too many AI requests. Please try again later.',
      retryAfter: '15 minutes'
    });
  }
});

module.exports = rateLimiter;
