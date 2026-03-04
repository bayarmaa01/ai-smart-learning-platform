const express = require('express');
const router = express.Router();
const { verifyToken, authorize } = require('../middleware/auth');
const { query } = require('../db/connection');

router.use(verifyToken, authorize('admin', 'super_admin'));

router.get('/stats', async (req, res) => {
  const [users, courses, revenue, subscriptions] = await Promise.all([
    query('SELECT COUNT(*) AS total, COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL \'24h\') AS today FROM users'),
    query('SELECT COUNT(*) AS total, COUNT(*) FILTER (WHERE status = \'published\') AS published FROM courses'),
    query('SELECT COALESCE(SUM(sp.price_monthly), 0) AS monthly FROM subscriptions s JOIN subscription_plans sp ON s.plan_id = sp.id WHERE s.status = \'active\''),
    query('SELECT COUNT(*) AS active FROM subscriptions WHERE status = \'active\''),
  ]);

  res.json({
    success: true,
    stats: {
      users: { total: parseInt(users.rows[0].total), today: parseInt(users.rows[0].today) },
      courses: { total: parseInt(courses.rows[0].total), published: parseInt(courses.rows[0].published) },
      revenue: { monthly: parseFloat(revenue.rows[0].monthly) },
      subscriptions: { active: parseInt(subscriptions.rows[0].active) },
    },
  });
});

router.get('/users', async (req, res) => {
  const { page = 1, limit = 20, search, role } = req.query;
  const offset = (page - 1) * limit;
  const params = [];
  const conditions = [];

  if (search) {
    params.push(`%${search}%`);
    conditions.push(`(email ILIKE $${params.length} OR first_name ILIKE $${params.length} OR last_name ILIKE $${params.length})`);
  }
  if (role) {
    params.push(role);
    conditions.push(`role = $${params.length}`);
  }

  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
  const result = await query(
    `SELECT id, email, first_name, last_name, role, is_active, created_at, last_login_at
     FROM users ${where} ORDER BY created_at DESC LIMIT $${params.length + 1} OFFSET $${params.length + 2}`,
    [...params, parseInt(limit), offset]
  );

  const count = await query(`SELECT COUNT(*) FROM users ${where}`, params);
  res.json({ success: true, users: result.rows, total: parseInt(count.rows[0].count) });
});

router.patch('/users/:id/role', async (req, res) => {
  const { role } = req.body;
  const validRoles = ['student', 'instructor', 'admin'];
  if (!validRoles.includes(role)) {
    return res.status(400).json({ success: false, error: { message: 'Invalid role' } });
  }
  await query('UPDATE users SET role = $1 WHERE id = $2', [role, req.params.id]);
  res.json({ success: true, message: 'Role updated' });
});

router.patch('/users/:id/status', async (req, res) => {
  const { isActive } = req.body;
  await query('UPDATE users SET is_active = $1 WHERE id = $2', [isActive, req.params.id]);
  res.json({ success: true, message: `User ${isActive ? 'activated' : 'deactivated'}` });
});

router.get('/stats', async (req, res) => {
  const [users, courses, revenue, subscriptions] = await Promise.all([
    query('SELECT COUNT(*) AS total FROM users WHERE tenant_id = $1', [req.tenantId || '00000000-0000-0000-0000-000000000001']),
    query('SELECT COUNT(*) AS total FROM courses WHERE tenant_id = $1', [req.tenantId || '00000000-0000-0000-0000-000000000001']),
    query(`SELECT COALESCE(SUM(sp.price_monthly * 100), 0) AS total
           FROM subscriptions s JOIN subscription_plans sp ON s.plan_id = sp.id
           WHERE s.status = 'active'`),
    query("SELECT COUNT(*) AS active FROM subscriptions WHERE status = 'active'"),
  ]);

  res.json({
    success: true,
    stats: {
      totalUsers: parseInt(users.rows[0]?.total || 0),
      totalCourses: parseInt(courses.rows[0]?.total || 0),
      totalRevenue: parseFloat(revenue.rows[0]?.total || 0),
      activeSubscriptions: parseInt(subscriptions.rows[0]?.active || 0),
    },
  });
});

router.get('/analytics/revenue', async (req, res) => {
  const result = await query(
    `SELECT TO_CHAR(DATE_TRUNC('month', s.created_at), 'Mon') AS month,
            COALESCE(SUM(sp.price_monthly), 0) AS revenue
     FROM subscriptions s
     JOIN subscription_plans sp ON s.plan_id = sp.id
     WHERE s.created_at >= NOW() - INTERVAL '6 months'
     GROUP BY DATE_TRUNC('month', s.created_at)
     ORDER BY DATE_TRUNC('month', s.created_at)`
  );
  res.json({ success: true, data: result.rows });
});

router.get('/analytics/user-growth', async (req, res) => {
  const result = await query(
    `SELECT TO_CHAR(DATE_TRUNC('month', created_at), 'Mon') AS month,
            COUNT(*) AS users
     FROM users
     WHERE created_at >= NOW() - INTERVAL '6 months'
     GROUP BY DATE_TRUNC('month', created_at)
     ORDER BY DATE_TRUNC('month', created_at)`
  );
  res.json({ success: true, data: result.rows.map((r) => ({ ...r, users: parseInt(r.users) })) });
});

router.get('/health', async (req, res) => {
  const { connectDB } = require('../db/connection');
  const { connectRedis } = require('../cache/redis');
  const axios = require('axios');

  const services = [];

  try {
    await query('SELECT 1');
    services.push({ name: 'PostgreSQL', status: 'healthy', uptime: 99 });
  } catch {
    services.push({ name: 'PostgreSQL', status: 'unhealthy', uptime: 0 });
  }

  try {
    const { getCache } = require('../cache/redis');
    await getCache('health:check');
    services.push({ name: 'Redis', status: 'healthy', uptime: 99 });
  } catch {
    services.push({ name: 'Redis', status: 'unhealthy', uptime: 0 });
  }

  try {
    await axios.get(`${process.env.AI_SERVICE_URL || 'http://localhost:8000'}/health`, { timeout: 3000 });
    services.push({ name: 'AI Service', status: 'healthy', uptime: 95 });
  } catch {
    services.push({ name: 'AI Service', status: 'degraded', uptime: 0 });
  }

  services.push({ name: 'API Server', status: 'healthy', uptime: 100 });

  res.json({ success: true, services });
});

let platformSettings = {
  platformName: 'EduAI Platform',
  supportEmail: 'support@eduai.com',
  enableAIChat: true,
  enableRegistration: true,
  requireEmailVerification: true,
  maintenanceMode: false,
  defaultLanguage: 'en',
  sessionTimeout: 24,
  maxLoginAttempts: 5,
};

router.get('/settings', async (req, res) => {
  res.json({ success: true, settings: platformSettings });
});

router.patch('/settings', async (req, res) => {
  platformSettings = { ...platformSettings, ...req.body };
  res.json({ success: true, settings: platformSettings, message: 'Settings updated' });
});

module.exports = router;
