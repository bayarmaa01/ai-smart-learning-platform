const request = require('supertest');
const { app } = require('../server');
const { query } = require('../db/connection');
const redisClient = require('../cache/redis');

jest.mock('../db/connection');
jest.mock('../cache/redis');

describe('Auth API', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    
    // Mock tenant resolution
    redisClient.get = jest.fn().mockResolvedValue(null);
    redisClient.set = jest.fn().mockResolvedValue('OK');
    
    // Mock tenant query for resolveTenant middleware
    query.mockImplementation((queryText, params) => {
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
  });

  describe('POST /api/v1/auth/register', () => {
    it('should register a new user successfully', async () => {
      const mockQuery = jest.fn();
      query.mockImplementation(mockQuery);
      
      // Mock tenant query (first call)
      mockQuery.mockResolvedValueOnce({
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
      
      // Mock user existence check
      mockQuery.mockResolvedValueOnce({ rows: [] });
      
      // Mock user creation
      mockQuery.mockResolvedValueOnce({
        rows: [{
          id: 'test-uuid',
          email: 'test@example.com',
          first_name: 'Test',
          last_name: 'User',
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

      console.log('Register response:', res.status, res.body);
      expect(res.status).toBe(201);
      expect(res.body).toHaveProperty('accessToken');
      expect(res.body.user).toHaveProperty('email', 'test@example.com');
    });

    it('should reject registration with weak password', async () => {
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
      query.mockResolvedValueOnce({
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

      expect(res.status).toBe(409);
    });
  });

  describe('POST /api/v1/auth/login', () => {
    it('should login successfully with valid credentials', async () => {
      const bcrypt = require('bcryptjs');
      const hashedPassword = await bcrypt.hash('SecurePass123!', 12);
      
      const mockQuery = jest.fn();
      query.mockImplementation(mockQuery);
      
      // Mock tenant query (first call)
      mockQuery.mockResolvedValueOnce({
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

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('accessToken');
    });

    it('should reject login with wrong password', async () => {
      const bcrypt = require('bcryptjs');
      const hashedPassword = await bcrypt.hash('CorrectPass123!', 12);

      query
        .mockResolvedValueOnce({
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
        })
        .mockResolvedValueOnce({ rows: [] });

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
      query.mockResolvedValueOnce({ rows: [] });

      const res = await request(app)
        .post('/api/v1/auth/login')
        .set('X-Tenant-ID', 'default')
        .send({
          email: 'nonexistent@example.com',
          password: 'SecurePass123!',
        });

      expect(res.status).toBe(401);
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

      query.mockResolvedValueOnce({
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

      expect(res.status).toBe(200);
      expect(res.body.user).toHaveProperty('email', 'test@example.com');
    });

    it('should reject request without token', async () => {
      const res = await request(app)
        .get('/api/v1/auth/me')
        .set('X-Tenant-ID', 'default');

      expect(res.status).toBe(401);
    });
  });
});
