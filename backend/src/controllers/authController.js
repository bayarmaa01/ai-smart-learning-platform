const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { query } = require('../db/connection');
const { setCache, deleteCache, getCache, incrementCounter } = require('../cache/redis');
const { AppError } = require('../middleware/errorHandler');
const { logger } = require('../utils/logger');
const { sendPasswordResetEmail, sendWelcomeEmail, sendVerificationEmail } = require('../utils/email');

const generateTokens = (userId, role, tenantId) => {
  const accessToken = jwt.sign(
    { userId, role, tenantId },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || '15m' }
  );

  const refreshToken = jwt.sign(
    { userId, type: 'refresh' },
    process.env.JWT_REFRESH_SECRET,
    { expiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '7d' }
  );

  return { accessToken, refreshToken };
};

const register = async (req, res) => {
  const { email, password, firstName, lastName, role = 'student', tenantId } = req.body;

  // Validation
  if (!email || !password || !firstName || !lastName) {
    throw new AppError('All fields are required', 400, 'VALIDATION_ERROR');
  }

  if (!/\S+@\S+\.\S+/.test(email)) {
    throw new AppError('Invalid email format', 400, 'INVALID_EMAIL');
  }

  if (password.length < 8) {
    throw new AppError('Password must be at least 8 characters', 400, 'PASSWORD_TOO_SHORT');
  }

  if (!['student', 'instructor'].includes(role)) {
    throw new AppError('Invalid role. Must be student or instructor', 400, 'INVALID_ROLE');
  }

  // Check for existing user
  const resolvedTenantId = tenantId || '00000000-0000-0000-0000-000000000001';
  const existingUser = await query(
    'SELECT id FROM users WHERE email = $1 AND tenant_id = $2',
    [email, resolvedTenantId]
  );

  if (existingUser.rows.length > 0) {
    throw new AppError('Email already registered', 409, 'EMAIL_EXISTS');
  }

  // Rate limiting
  const failedAttempts = await incrementCounter(`register:${req.ip}`, 3600);
  if (failedAttempts > 10) {
    throw new AppError('Too many registration attempts', 429, 'RATE_LIMIT');
  }

  // Create user
  const passwordHash = await bcrypt.hash(password, 12);
  const verificationToken = crypto.randomBytes(32).toString('hex');

  const result = await query(
    `INSERT INTO users (email, password_hash, first_name, last_name, role, tenant_id, email_verification_token)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING id, email, first_name, last_name, role, tenant_id, language_preference`,
    [email, passwordHash, firstName, lastName, role, resolvedTenantId, verificationToken]
  );

  const user = result.rows[0];
  const { accessToken, refreshToken } = generateTokens(user.id, user.role, user.tenant_id);

  // Store refresh token
  const refreshTokenHash = crypto.createHash('sha256').update(refreshToken).digest('hex');
  await query(
    `INSERT INTO refresh_tokens (user_id, token_hash, ip_address, expires_at)
     VALUES ($1, $2, $3, NOW() + INTERVAL '7 days')`,
    [user.id, refreshTokenHash, req.ip]
  );

  logger.info(`New user registered: ${email} with role: ${role}`);

  // Send welcome + verification emails (non-blocking)
  sendWelcomeEmail(email, firstName).catch((err) => logger.error('Welcome email failed:', err));
  sendVerificationEmail(email, firstName, verificationToken).catch((err) => logger.error('Verification email failed:', err));

  res.status(201).json({
    success: true,
    accessToken,
    refreshToken,
    user: {
      id: user.id,
      email: user.email,
      firstName: user.first_name,
      lastName: user.last_name,
      role: user.role,
      tenantId: user.tenant_id,
    },
  });
};

const login = async (req, res) => {
  const { email, password } = req.body;

  const lockKey = `login:lock:${email}`;
  const isLocked = await getCache(lockKey);
  if (isLocked) {
    throw new AppError('Account temporarily locked. Please try again in 15 minutes.', 423, 'ACCOUNT_LOCKED');
  }

  const result = await query(
    `SELECT id, email, password_hash, first_name, last_name, role, tenant_id,
            is_active, failed_login_attempts, language_preference
     FROM users WHERE email = $1`,
    [email]
  );

  const user = result.rows[0];

  if (!user || !(await bcrypt.compare(password, user.password_hash))) {
    if (user) {
      const attempts = user.failed_login_attempts + 1;
      await query('UPDATE users SET failed_login_attempts = $1 WHERE id = $2', [attempts, user.id]);
      if (attempts >= 5) {
        await setCache(lockKey, true, 15 * 60);
      }
    }
    throw new AppError('Invalid email or password', 401, 'INVALID_CREDENTIALS');
  }

  if (!user.is_active) {
    throw new AppError('Account is deactivated', 401, 'ACCOUNT_DEACTIVATED');
  }

  await query(
    'UPDATE users SET failed_login_attempts = 0, last_login_at = NOW(), login_count = login_count + 1 WHERE id = $1',
    [user.id]
  );

  const { accessToken, refreshToken } = generateTokens(user.id, user.role, user.tenant_id);

  const refreshTokenHash = crypto.createHash('sha256').update(refreshToken).digest('hex');
  await query(
    `INSERT INTO refresh_tokens (user_id, token_hash, ip_address, expires_at)
     VALUES ($1, $2, $3, NOW() + INTERVAL '7 days')`,
    [user.id, refreshTokenHash, req.ip]
  );

  logger.info(`User logged in: ${email}`);

  res.json({
    success: true,
    accessToken,
    refreshToken,
    user: {
      id: user.id,
      email: user.email,
      firstName: user.first_name,
      lastName: user.last_name,
      role: user.role,
      tenantId: user.tenant_id,
      languagePreference: user.language_preference,
    },
  });
};

const logout = async (req, res) => {
  const authHeader = req.headers.authorization;
  const token = authHeader?.split(' ')[1];

  if (token) {
    const decoded = jwt.decode(token);
    const ttl = decoded?.exp ? decoded.exp - Math.floor(Date.now() / 1000) : 900;
    if (ttl > 0) {
      await setCache(`blacklist:${token}`, true, ttl);
    }
  }

  await deleteCache(`user:${req.user.id}`);

  res.json({ success: true, message: 'Logged out successfully' });
};

const refreshToken = async (req, res) => {
  const { refreshToken: token } = req.body;

  if (!token) {
    throw new AppError('Refresh token required', 400, 'TOKEN_REQUIRED');
  }

  try {
    jwt.verify(token, process.env.JWT_REFRESH_SECRET);
  } catch {
    throw new AppError('Invalid or expired refresh token', 401, 'INVALID_REFRESH_TOKEN');
  }

  const tokenHash = crypto.createHash('sha256').update(token).digest('hex');
  const result = await query(
    `SELECT rt.id, u.id as user_id, u.role, u.tenant_id, u.is_active
     FROM refresh_tokens rt
     JOIN users u ON rt.user_id = u.id
     WHERE rt.token_hash = $1 AND rt.revoked_at IS NULL AND rt.expires_at > NOW()`,
    [tokenHash]
  );

  if (!result.rows.length) {
    throw new AppError('Refresh token not found or expired', 401, 'INVALID_REFRESH_TOKEN');
  }

  const { user_id, role, tenant_id, is_active } = result.rows[0];

  if (!is_active) {
    throw new AppError('Account is deactivated', 401, 'ACCOUNT_DEACTIVATED');
  }

  await query('UPDATE refresh_tokens SET revoked_at = NOW() WHERE token_hash = $1', [tokenHash]);

  const { accessToken, refreshToken: newRefreshToken } = generateTokens(user_id, role, tenant_id);

  const newTokenHash = crypto.createHash('sha256').update(newRefreshToken).digest('hex');
  await query(
    `INSERT INTO refresh_tokens (user_id, token_hash, ip_address, expires_at)
     VALUES ($1, $2, $3, NOW() + INTERVAL '7 days')`,
    [user_id, newTokenHash, req.ip]
  );

  res.json({ success: true, accessToken, refreshToken: newRefreshToken });
};

const getMe = async (req, res) => {
  const result = await query(
    `SELECT id, email, first_name, last_name, role, tenant_id, avatar_url, bio,
            language_preference, is_email_verified, created_at, last_login_at
     FROM users WHERE id = $1`,
    [req.user.id]
  );

  const user = result.rows[0];
  res.json({
    success: true,
    user: {
      id: user.id,
      email: user.email,
      firstName: user.first_name,
      lastName: user.last_name,
      role: user.role,
      tenantId: user.tenant_id,
      avatarUrl: user.avatar_url,
      bio: user.bio,
      languagePreference: user.language_preference,
      isEmailVerified: user.is_email_verified,
      createdAt: user.created_at,
      lastLoginAt: user.last_login_at,
    },
  });
};

const forgotPassword = async (req, res) => {
  const { email } = req.body;

  const result = await query('SELECT id FROM users WHERE email = $1', [email]);

  if (result.rows.length > 0) {
    const resetToken = crypto.randomBytes(32).toString('hex');
    const resetExpires = new Date(Date.now() + 60 * 60 * 1000);

    await query(
      'UPDATE users SET password_reset_token = $1, password_reset_expires = $2 WHERE id = $3',
      [resetToken, resetExpires, result.rows[0].id]
    );

    const userResult = await query('SELECT first_name FROM users WHERE id = $1', [result.rows[0].id]);
    const firstName = userResult.rows[0]?.first_name || 'User';

    sendPasswordResetEmail(email, resetToken, firstName).catch((err) =>
      logger.error('Password reset email failed:', err)
    );

    logger.info(`Password reset requested for: ${email}`);
  }

  res.json({ success: true, message: 'If the email exists, a reset link has been sent.' });
};

const resetPassword = async (req, res) => {
  const { token, password } = req.body;

  const result = await query(
    'SELECT id FROM users WHERE password_reset_token = $1 AND password_reset_expires > NOW()',
    [token]
  );

  if (!result.rows.length) {
    throw new AppError('Invalid or expired reset token', 400, 'INVALID_RESET_TOKEN');
  }

  const passwordHash = await bcrypt.hash(password, 12);
  await query(
    'UPDATE users SET password_hash = $1, password_reset_token = NULL, password_reset_expires = NULL WHERE id = $2',
    [passwordHash, result.rows[0].id]
  );

  await deleteCache(`user:${result.rows[0].id}`);

  res.json({ success: true, message: 'Password reset successfully' });
};

const verifyEmail = async (req, res) => {
  const { token } = req.params;

  const result = await query(
    'UPDATE users SET is_email_verified = TRUE, email_verification_token = NULL WHERE email_verification_token = $1 RETURNING id',
    [token]
  );

  if (!result.rows.length) {
    throw new AppError('Invalid verification token', 400, 'INVALID_TOKEN');
  }

  res.json({ success: true, message: 'Email verified successfully' });
};

module.exports = { register, login, logout, refreshToken, getMe, forgotPassword, resetPassword, verifyEmail };
