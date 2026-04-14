const jwt = require('jsonwebtoken');
const { query } = require('../db/connection');
const { getCache, setCache } = require('../cache/redis');
const { AppError } = require('./errorHandler');

const normalizeRole = (role) => {
  if (role === 'teacher') return 'instructor';
  return role;
};

const verifyToken = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new AppError('No token provided', 401, 'UNAUTHORIZED');
    }

    const token = authHeader.split(' ')[1];

    const cacheKey = `blacklist:${token}`;
    const isBlacklisted = await getCache(cacheKey);
    if (isBlacklisted) {
      throw new AppError('Token has been revoked', 401, 'TOKEN_REVOKED');
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    const cacheUserKey = `user:${decoded.userId}`;
    let user = await getCache(cacheUserKey);

    if (!user) {
      const result = await query(
        'SELECT id, email, first_name, last_name, role, tenant_id, is_active, language_preference FROM users WHERE id = $1',
        [decoded.userId]
      );

      if (!result.rows.length) {
        throw new AppError('User not found', 401, 'USER_NOT_FOUND');
      }

      user = result.rows[0];
      user.role = normalizeRole(user.role);
      await setCache(cacheUserKey, user, 300);
    }

    if (!user.is_active) {
      throw new AppError('Account is deactivated', 401, 'ACCOUNT_DEACTIVATED');
    }

    req.user = user;
    req.tenantId = req.headers['x-tenant-id'] || user.tenant_id;
    next();
  } catch (err) {
    if (err.name === 'JsonWebTokenError') {
      return next(new AppError('Invalid token', 401, 'INVALID_TOKEN'));
    }
    if (err.name === 'TokenExpiredError') {
      return next(new AppError('Token expired', 401, 'TOKEN_EXPIRED'));
    }
    next(err);
  }
};

const authorize = (...roles) => {
  const normalizedRoles = roles.map(normalizeRole);
  return (req, res, next) => {
    if (!req.user) {
      return next(new AppError('Authentication required', 401, 'UNAUTHORIZED'));
    }
    if (!normalizedRoles.includes(normalizeRole(req.user.role))) {
      return next(new AppError('Insufficient permissions', 403, 'FORBIDDEN'));
    }
    next();
  };
};

const optionalAuth = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return next();
    }
    await verifyToken(req, res, next);
  } catch (error) {
    return next();
  }
};

const authMiddleware = async (req, res, next) => {
  await verifyToken(req, res, next);
};

module.exports = { verifyToken, authorize, optionalAuth, authMiddleware };
