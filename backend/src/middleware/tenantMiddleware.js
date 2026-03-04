const { query } = require('../db/connection');
const { getCache, setCache } = require('../cache/redis');
const { AppError } = require('./errorHandler');

const resolveTenant = async (req, res, next) => {
  try {
    const tenantId = req.headers['x-tenant-id'] || req.user?.tenant_id;

    if (!tenantId) {
      req.tenant = null;
      return next();
    }

    const cacheKey = `tenant:${tenantId}`;
    let tenant = await getCache(cacheKey);

    if (!tenant) {
      const result = await query(
        'SELECT id, name, slug, settings, subscription_plan, max_users, is_active FROM tenants WHERE id = $1',
        [tenantId]
      );

      if (!result.rows.length) {
        throw new AppError('Tenant not found', 404, 'TENANT_NOT_FOUND');
      }

      tenant = result.rows[0];
      await setCache(cacheKey, tenant, 600);
    }

    if (!tenant.is_active) {
      throw new AppError('Tenant account is suspended', 403, 'TENANT_SUSPENDED');
    }

    req.tenant = tenant;
    req.tenantId = tenant.id;
    next();
  } catch (err) {
    next(err);
  }
};

module.exports = { resolveTenant };
