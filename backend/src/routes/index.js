const express = require('express');
const router = express.Router();

const authRoutes = require('./auth');
const courseRoutes = require('./courses');
const userRoutes = require('./users');
const aiRoutes = require('./ai');
const subscriptionRoutes = require('./subscriptions');
const adminRoutes = require('./admin');
const uploadRoutes = require('./upload');

router.use('/auth', authRoutes);
router.use('/courses', courseRoutes);
router.use('/users', userRoutes);
router.use('/ai', aiRoutes);
router.use('/subscriptions', subscriptionRoutes);
router.use('/admin', adminRoutes);
router.use('/upload', uploadRoutes);

router.get('/status', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

module.exports = router;
