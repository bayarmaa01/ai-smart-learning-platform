const express = require('express');
const router = express.Router();
const rateLimit = require('express-rate-limit');
const { body } = require('express-validator');
const aiController = require('../controllers/aiController');
const { verifyToken } = require('../middleware/auth');
const { validate } = require('../middleware/validate');

const aiLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 30,
  message: { error: 'Too many AI requests, please slow down.' },
  keyGenerator: (req) => req.user?.id || req.ip,
});

router.use(verifyToken);

router.post('/chat', aiLimiter, [
  body('message').trim().isLength({ min: 1, max: 2000 }).withMessage('Message must be 1-2000 characters'),
  body('session_id').optional().isUUID(),
], validate, aiController.chat);

router.get('/chat/history/:sessionId', aiController.getChatHistory);
router.post('/recommendations', aiController.getRecommendations);
router.delete('/chat/:sessionId', aiController.clearSession);

module.exports = router;
