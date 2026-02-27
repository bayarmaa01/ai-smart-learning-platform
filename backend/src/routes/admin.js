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

module.exports = router;
