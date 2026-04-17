const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { query } = require('../db/connection');

const generateTokens = (userId, role, tenantId) => {
  const accessToken = jwt.sign(
    { userId, role, tenantId },
    process.env.JWT_SECRET || 'fallback-secret',
    { expiresIn: '15m' }
  );

  const refreshToken = jwt.sign(
    { userId, type: 'refresh' },
    process.env.JWT_REFRESH_SECRET || 'fallback-refresh-secret',
    { expiresIn: '7d' }
  );

  return { accessToken, refreshToken };
};

const register = async (req, res) => {
  try {
    console.log('Register request received:', req.body);
    
    const { email, password, firstName, lastName, role = 'student', tenantId } = req.body;

    // Basic validation
    if (!email || !password || !firstName) {
      return res.status(400).json({
        success: false,
        error: {
          message: 'All fields are required',
          code: 'VALIDATION_ERROR'
        }
      });
    }

    // Email validation
    if (!/\S+@\S+\.\S+/.test(email)) {
      return res.status(400).json({
        success: false,
        error: {
          message: 'Invalid email format',
          code: 'INVALID_EMAIL'
        }
      });
    }

    // Password validation
    if (password.length < 6) {
      return res.status(400).json({
        success: false,
        error: {
          message: 'Password must be at least 6 characters',
          code: 'PASSWORD_TOO_SHORT'
        }
      });
    }

    // Map "teacher" to "instructor"
    let normalizedRole = role;
    if (role === 'teacher') {
      normalizedRole = 'instructor';
    }

    if (!['student', 'instructor'].includes(normalizedRole)) {
      return res.status(400).json({
        success: false,
        error: {
          message: 'Invalid role. Must be student or instructor',
          code: 'INVALID_ROLE'
        }
      });
    }

    console.log('Validation passed, checking existing user...');

    // Check for existing user
    const resolvedTenantId = tenantId || '00000000-0000-0000-0000-000000000001';
    const existingUser = await query(
      'SELECT id FROM users WHERE email = $1 AND tenant_id = $2',
      [email, resolvedTenantId]
    );

    if (existingUser.rows.length > 0) {
      return res.status(409).json({
        success: false,
        error: {
          message: 'Email already registered',
          code: 'EMAIL_EXISTS'
        }
      });
    }

    console.log('Creating new user...');

    // Create user
    const passwordHash = await bcrypt.hash(password, 12);
    const verificationToken = crypto.randomBytes(32).toString('hex');

    const result = await query(
      `INSERT INTO users (email, password_hash, first_name, last_name, role, tenant_id, email_verification_token)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING id, email, first_name, last_name, role, tenant_id, language_preference`,
      [email, passwordHash, firstName, lastName || 'User', normalizedRole, resolvedTenantId, verificationToken]
    );

    const user = result.rows[0];
    const { accessToken, refreshToken } = generateTokens(user.id, user.role, user.tenant_id);

    console.log('User created successfully');

    return res.status(201).json({
      success: true,
      data: {
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
        }
      }
    });
  } catch (error) {
    console.error('Registration error:', error);
    return res.status(500).json({
      success: false,
      error: {
        message: 'Internal server error during registration',
        code: 'REGISTRATION_ERROR'
      }
    });
  }
};

const login = async (req, res) => {
  try {
    console.log('Login request received:', { email: req.body.email });
    
    const { email, password } = req.body;

    // Basic validation
    if (!email || !password) {
      return res.status(400).json({
        success: false,
        error: {
          message: 'Email and password are required',
          code: 'VALIDATION_ERROR'
        }
      });
    }

    console.log('Finding user...');

    // Find user
    const result = await query(
      `SELECT id, email, password_hash, first_name, last_name, role, tenant_id, is_active
       FROM users WHERE email = $1`,
      [email]
    );

    const user = result.rows[0];

    if (!user || !(await bcrypt.compare(password, user.password_hash))) {
      return res.status(401).json({
        success: false,
        error: {
          message: 'Invalid email or password',
          code: 'INVALID_CREDENTIALS'
        }
      });
    }

    if (!user.is_active) {
      return res.status(401).json({
        success: false,
        error: {
          message: 'Account is deactivated',
          code: 'ACCOUNT_DEACTIVATED'
        }
      });
    }

    console.log('User found, generating tokens...');

    // Generate tokens
    const { accessToken, refreshToken } = generateTokens(user.id, user.role, user.tenant_id);

    // Update last login
    await query(
      'UPDATE users SET last_login_at = NOW() WHERE id = $1',
      [user.id]
    );

    console.log('Login successful');

    return res.json({
      success: true,
      data: {
        accessToken,
        refreshToken,
        user: {
          id: user.id,
          email: user.email,
          firstName: user.first_name,
          lastName: user.last_name,
          role: user.role,
          tenantId: user.tenant_id,
        }
      }
    });
  } catch (error) {
    console.error('Login error:', error);
    return res.status(500).json({
      success: false,
      error: {
        message: 'Internal server error during login',
        code: 'LOGIN_ERROR'
      }
    });
  }
};

// Add missing functions that routes expect
const refreshToken = async (req, res) => {
  try {
    const { refreshToken } = req.body;
    
    if (!refreshToken) {
      return res.status(400).json({
        success: false,
        error: {
          message: 'Refresh token is required',
          code: 'REFRESH_TOKEN_REQUIRED'
        }
      });
    }

    // For now, return a simple response
    return res.json({
      success: true,
      message: 'Token refresh endpoint (simplified)'
    });
  } catch (error) {
    console.error('Refresh token error:', error);
    return res.status(500).json({
      success: false,
      error: {
        message: 'Internal server error during token refresh',
        code: 'REFRESH_ERROR'
      }
    });
  }
};

const getMe = async (req, res) => {
  try {
    // For now, return a simple response
    return res.json({
      success: true,
      data: {
        user: {
          id: 'temp-id',
          email: 'temp@example.com',
          firstName: 'Temp',
          lastName: 'User',
          role: 'student'
        }
      }
    });
  } catch (error) {
    console.error('Get me error:', error);
    return res.status(500).json({
      success: false,
      error: {
        message: 'Internal server error getting user info',
        code: 'GET_ME_ERROR'
      }
    });
  }
};

module.exports = { register, login, refreshToken, getMe };
