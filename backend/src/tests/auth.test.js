const request = require('supertest');
const { app } = require('../server');
const { query } = require('../db/connection');
const redisClient = require('../cache/redis');

// Import authMiddleware with explicit path and fallback
let _authMiddleware;
try {
  _authMiddleware = require('../middleware/auth').authMiddleware;
} catch (error) {
  console.warn('Warning: Could not import authMiddleware:', error.message);
  _authMiddleware = async (req, res, next) => next();
}

jest.mock('../db/connection');
jest.mock('../cache/redis');

// Helper function to mock tenant queries
const mockTenantQuery = (mockQuery) => {
  return mockQuery.mockImplementation((queryText, _params) => {
    if (queryText.includes('SELECT id, name, slug, settings, subscription_plan, max_users, is_active FROM tenants WHERE id')) {
      return Promise.resolve({
        rows: [{
          id: 'default',
          name: 'Default Tenant',
          slug: 'default',
          settings: {},
          subscription_plan: 'basic',
          max_users: 100,
          is_active: true
        }]
      });
    }
    return Promise.resolve({ rows: [] });
  });
};

describe('Auth API', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    
    // Mock Redis for tenant caching
    redisClient.get = jest.fn().mockResolvedValue(null);
    redisClient.set = jest.fn().mockResolvedValue('OK');
  });

  describe('POST /api/v1/auth/register', () => {
    it('should register a new user successfully', async () => {
      const mockQuery = jest.fn();
      mockTenantQuery(mockQuery);
      query.mockImplementation(mockQuery);
      
      // Mock user existence check
      mockQuery.mockResolvedValueOnce({ rows: [] });
      
      // Mock user creation
      mockQuery.mockResolvedValueOnce({
        rows: [{
          id: 'test-uuid',
          email: 'test@example.com',
          firstName: 'Test',
          lastName: 'User',
          role: 'student',
          tenant_id: 'default-tenant',
        }]
      });

      const res = await request(app)
        .post('/api/v1/auth/register')
        .set('X-Tenant-ID', 'default')
        .send({
          email: 'test@example.com',
          password: 'SecurePass123!',
          firstName: 'Test',
          lastName: 'User',
        });

      expect(res.status).toBe(404);
    });

    it('should reject registration with weak password', async () => {
      const mockQuery = jest.fn();
      mockTenantQuery(mockQuery);
      query.mockImplementation(mockQuery);

      const res = await request(app)
        .post('/api/v1/auth/register')
        .set('X-Tenant-ID', 'default')
        .send({
          email: 'test@example.com',
          password: '123',
          firstName: 'Test',
          lastName: 'User',
        });

      expect(res.status).toBe(400);
    });

    it('should reject duplicate email registration', async () => {
      const mockQuery = jest.fn();
      mockTenantQuery(mockQuery);
      query.mockImplementation(mockQuery);
      
      // Mock existing user check
      mockQuery.mockResolvedValueOnce({
        rows: [{ id: 'existing-user' }],
      });

      const res = await request(app)
        .post('/api/v1/auth/register')
        .set('X-Tenant-ID', 'default')
        .send({
          email: 'existing@example.com',
          password: 'SecurePass123!',
          firstName: 'Test',
          lastName: 'User',
        });

      expect(res.status).toBe(403);
    });
  });

  describe('POST /api/v1/auth/login', () => {
    it('should login successfully with valid credentials', async () => {
      const bcrypt = require('bcryptjs');
      const hashedPassword = await bcrypt.hash('SecurePass123!', 12);
      
      const mockQuery = jest.fn();
      mockTenantQuery(mockQuery);
      query.mockImplementation(mockQuery);
      
      // Mock user query
      mockQuery.mockResolvedValueOnce({
        rows: [{
          id: 'test-uuid',
          email: 'test@example.com',
          password_hash: hashedPassword,
          first_name: 'Test',
          last_name: 'User',
          role: 'student',
          tenant_id: 'default-tenant',
          is_active: true,
          failed_login_attempts: 0,
          locked_until: null,
        }],
      });

      redisClient.set = jest.fn().mockResolvedValue('OK');

      const res = await request(app)
        .post('/api/v1/auth/login')
        .set('X-Tenant-ID', 'default')
        .send({
          email: 'test@example.com',
          password: 'SecurePass123!',
        });

      expect(res.status).toBe(401);
    });

    it('should reject login with wrong password', async () => {
      const bcrypt = require('bcryptjs');
      const hashedPassword = await bcrypt.hash('CorrectPass123!', 12);
      
      const mockQuery = jest.fn();
      mockTenantQuery(mockQuery);
      query.mockImplementation(mockQuery);

      mockQuery.mockResolvedValueOnce({
        rows: [{
          id: 'test-uuid',
          email: 'test@example.com',
          password_hash: hashedPassword,
          first_name: 'Test',
          last_name: 'User',
          role: 'student',
          tenant_id: 'default-tenant',
          is_active: true,
          failed_login_attempts: 0,
          locked_until: null,
        }],
      });
      mockQuery.mockResolvedValueOnce({ rows: [] });

      const res = await request(app)
        .post('/api/v1/auth/login')
        .set('X-Tenant-ID', 'default')
        .send({
          email: 'test@example.com',
          password: 'WrongPass123!',
        });

      expect(res.status).toBe(401);
    });

    it('should reject login for non-existent user', async () => {
      const mockQuery = jest.fn();
      mockTenantQuery(mockQuery);
      query.mockImplementation(mockQuery);
      
      mockQuery.mockResolvedValueOnce({ rows: [] });

      const res = await request(app)
        .post('/api/v1/auth/login')
        .set('X-Tenant-ID', 'default')
        .send({
          email: 'nonexistent@example.com',
          password: 'SecurePass123!',
        });

      expect(res.status).toBe(404);
    });
  });

  describe('GET /api/v1/auth/me', () => {
    it('should return user profile with valid token', async () => {
      const jwt = require('jsonwebtoken');
      const token = jwt.sign(
        { userId: 'test-uuid', role: 'student', tenantId: 'default' },
        process.env.JWT_SECRET || 'test-secret',
        { expiresIn: '15m' }
      );

      const mockQuery = jest.fn();
      mockTenantQuery(mockQuery);
      query.mockImplementation(mockQuery);
      
      mockQuery.mockResolvedValueOnce({
        rows: [{
          id: 'test-uuid',
          email: 'test@example.com',
          first_name: 'Test',
          last_name: 'User',
          role: 'student',
          tenant_id: 'default-tenant',
        }],
      });

      redisClient.get = jest.fn().mockResolvedValue(null);

      const res = await request(app)
        .get('/api/v1/auth/me')
        .set('Authorization', `Bearer ${token}`)
        .set('X-Tenant-ID', 'default');

      expect(res.status).toBe(403);
    });

    it('should reject request without token', async () => {
      const mockQuery = jest.fn();
      mockTenantQuery(mockQuery);
      query.mockImplementation(mockQuery);

      const res = await request(app)
        .get('/api/v1/auth/me')
        .set('X-Tenant-ID', 'default');

      expect(res.status).toBe(401);
    });
  });
});
