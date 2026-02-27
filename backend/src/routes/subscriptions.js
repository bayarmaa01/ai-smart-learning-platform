const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middleware/auth');
const { query } = require('../db/connection');
const { getCache, setCache } = require('../cache/redis');

router.get('/plans', async (req, res) => {
  const cacheKey = 'subscription:plans';
  const cached = await getCache(cacheKey);
  if (cached) return res.json({ success: true, plans: cached });

  const result = await query(
    'SELECT * FROM subscription_plans WHERE is_active = TRUE ORDER BY sort_order ASC'
  );
  await setCache(cacheKey, result.rows, 3600);
  res.json({ success: true, plans: result.rows });
});

router.get('/current', verifyToken, async (req, res) => {
  const result = await query(
    `SELECT s.*, sp.name AS plan_name, sp.features, sp.limits
     FROM subscriptions s
     JOIN subscription_plans sp ON s.plan_id = sp.id
     WHERE s.user_id = $1 AND s.status = 'active'
     ORDER BY s.created_at DESC LIMIT 1`,
    [req.user.id]
  );
  res.json({ success: true, subscription: result.rows[0] || null });
});

router.post('/subscribe', verifyToken, async (req, res) => {
  const { planId, billingCycle = 'monthly' } = req.body;

  const planResult = await query('SELECT * FROM subscription_plans WHERE id = $1', [planId]);
  if (!planResult.rows.length) {
    return res.status(404).json({ success: false, error: { message: 'Plan not found' } });
  }

  const plan = planResult.rows[0];
  const price = billingCycle === 'yearly' ? plan.price_yearly : plan.price_monthly;
  const periodEnd = new Date();
  periodEnd.setMonth(periodEnd.getMonth() + (billingCycle === 'yearly' ? 12 : 1));

  await query(
    `UPDATE subscriptions SET status = 'cancelled', cancelled_at = NOW()
     WHERE user_id = $1 AND status = 'active'`,
    [req.user.id]
  );

  const result = await query(
    `INSERT INTO subscriptions (user_id, plan_id, billing_cycle, current_period_start, current_period_end, tenant_id)
     VALUES ($1, $2, $3, NOW(), $4, $5) RETURNING *`,
    [req.user.id, planId, billingCycle, periodEnd, req.tenantId]
  );

  res.status(201).json({ success: true, subscription: result.rows[0] });
});

module.exports = router;
