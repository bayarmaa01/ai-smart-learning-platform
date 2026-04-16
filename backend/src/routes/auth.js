const express = require('express');
const { body, validationResult } = require('express-validator');
const { verifyToken } = require('../middleware/auth');
const { register, login, refreshToken, getMe } = require('../controllers/authController');

const router = express.Router();
const JWT_SECRET = process.env.JWT_SECRET || 'your-super-secret-jwt-key-change-in-production';

// Register endpoint
router.post('/register', [
  body('email').isEmail().normalizeEmail(),
  body('password').isLength({ min: 6 }),
  body('firstName').notEmpty().trim(),
  body('lastName').notEmpty().trim(),
  body('role').optional().isIn(['student', 'teacher'])
], register);

// Login endpoint
router.post('/login', [
  body('email').isEmail().normalizeEmail(),
  body('password').notEmpty()
], login);

// Refresh token endpoint
router.post('/refresh', refreshToken);

// Get current user profile
router.get('/me', verifyToken, getMe);

module.exports = router;
