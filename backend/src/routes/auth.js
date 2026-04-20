const express = require('express');
const { body } = require('express-validator');
const { verifyToken } = require('../middleware/auth');
const { register, login, refreshToken, getMe } = require('../controllers/authController');

const router = express.Router();

// Register endpoint
router.post('/register', [
  body('email').isEmail().normalizeEmail(),
  body('password').isLength({ min: 6 }),
  body('firstName').notEmpty().trim(),
  body('lastName').notEmpty().trim(),
  body('role').optional().isIn(['student', 'instructor'])
], register);

// Login endpoint
router.post('/login', [
  body('email').isEmail().normalizeEmail(),
  body('password').notEmpty()
], login);

// Refresh token endpoint
router.post('/refresh', refreshToken);

// Get current user profile
router.get('/me', verifyToken, (req, res, next) => {
  // Prevent caching
  res.set('Cache-Control', 'no-store, no-cache, must-revalidate');
  res.set('Pragma', 'no-cache');
  res.set('Expires', '0');
  next();
}, getMe);

module.exports = router;
