const express = require('express');
const router = express.Router();

const authRoutes = require('./auth');
const courseRoutes = require('./courses');
const userRoutes = require('./users');
const aiRoutes = require('./ai');
const subscriptionRoutes = require('./subscriptions');
const adminRoutes = require('./admin');
const uploadRoutes = require('./upload');
const examRoutes = require('./exams');
const attemptRoutes = require('./attempts');
const questionRoutes = require('./questions');
const proctoringRoutes = require('./proctoring');

router.use('/auth', authRoutes);
router.use('/courses', courseRoutes);
router.use('/users', userRoutes);
router.use('/ai', aiRoutes);
router.use('/subscriptions', subscriptionRoutes);
router.use('/admin', adminRoutes);
router.use('/upload', uploadRoutes);
router.use('/exams', examRoutes);
router.use('/attempts', attemptRoutes);
router.use('/questions', questionRoutes);
router.use('/proctoring', proctoringRoutes);

router.get('/status', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

module.exports = router;
