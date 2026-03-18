const request = require('supertest');
const { app } = require('../server');
const { query } = require('../db/connection');
const redisClient = require('../cache/redis');
const jwt = require('jsonwebtoken');

jest.mock('../db/connection');
jest.mock('../cache/redis');

const makeToken = (role = 'student') =>
  jwt.sign(
    { userId: 'test-uuid', role, tenantId: 'default' },
    process.env.JWT_SECRET || 'test-secret',
    { expiresIn: '15m' }
  );

// Helper function to mock tenant queries
const mockTenantQuery = (mockQuery) => {
  return mockQuery.mockImplementation((queryText, params) => {
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

describe('Courses API', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    
    // Mock Redis for tenant caching
    redisClient.get = jest.fn().mockResolvedValue(null);
    redisClient.set = jest.fn().mockResolvedValue('OK');
  });

  describe('GET /api/v1/courses', () => {
    it('should return list of published courses', async () => {
      const mockQuery = jest.fn();
      mockTenantQuery(mockQuery);
      query.mockImplementation(mockQuery);
      
      // Mock courses query
      mockQuery.mockResolvedValueOnce({
        rows: [
          {
            id: 'course-1',
            title: 'Introduction to AI',
            description: 'Learn AI basics',
            level: 'beginner',
            price: 0,
            is_published: true,
            instructor_name: 'John Doe',
            total_lessons: 10,
            total_enrollments: 150,
          },
        ],
      });

      const res = await request(app)
        .get('/api/v1/courses')
        .set('X-Tenant-ID', 'default');

      console.log('Courses response:', res.status, res.body);
      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('courses');
      expect(Array.isArray(res.body.courses)).toBe(true);
    });

    it('should filter courses by level', async () => {
      query.mockResolvedValueOnce({ rows: [] });

      const res = await request(app)
        .get('/api/v1/courses?level=beginner')
        .set('X-Tenant-ID', 'default');

      expect(res.status).toBe(200);
    });
  });

  describe('GET /api/v1/courses/:id', () => {
    it('should return course details', async () => {
      query.mockResolvedValueOnce({
        rows: [{
          id: 'course-1',
          title: 'Introduction to AI',
          description: 'Learn AI basics',
          level: 'beginner',
          price: 0,
          is_published: true,
        }],
      });

      const res = await request(app)
        .get('/api/v1/courses/course-1')
        .set('X-Tenant-ID', 'default');

      expect(res.status).toBe(200);
      expect(res.body.course).toHaveProperty('id', 'course-1');
    });

    it('should return 404 for non-existent course', async () => {
      query.mockResolvedValueOnce({ rows: [] });

      const res = await request(app)
        .get('/api/v1/courses/nonexistent')
        .set('X-Tenant-ID', 'default');

      expect(res.status).toBe(404);
    });
  });

  describe('POST /api/v1/courses/:id/enroll', () => {
    it('should enroll student in free course', async () => {
      const token = makeToken('student');

      query
        .mockResolvedValueOnce({
          rows: [{ id: 'course-1', price: 0, is_published: true }],
        })
        .mockResolvedValueOnce({ rows: [] })
        .mockResolvedValueOnce({
          rows: [{ id: 'enrollment-1', course_id: 'course-1', user_id: 'test-uuid' }],
        });

      const res = await request(app)
        .post('/api/v1/courses/course-1/enroll')
        .set('Authorization', `Bearer ${token}`)
        .set('X-Tenant-ID', 'default');

      expect(res.status).toBe(201);
    });

    it('should reject enrollment without authentication', async () => {
      const res = await request(app)
        .post('/api/v1/courses/course-1/enroll')
        .set('X-Tenant-ID', 'default');

      expect(res.status).toBe(401);
    });
  });

  describe('POST /api/v1/courses (admin)', () => {
    it('should create course as admin', async () => {
      const token = makeToken('admin');

      query.mockResolvedValueOnce({
        rows: [{
          id: 'new-course',
          title: 'New Course',
          description: 'Course description',
          level: 'intermediate',
          price: 29.99,
          is_published: false,
        }],
      });

      const res = await request(app)
        .post('/api/v1/courses')
        .set('Authorization', `Bearer ${token}`)
        .set('X-Tenant-ID', 'default')
        .send({
          title: 'New Course',
          description: 'Course description',
          level: 'intermediate',
          price: 29.99,
        });

      expect(res.status).toBe(201);
      expect(res.body.course).toHaveProperty('title', 'New Course');
    });

    it('should reject course creation by student', async () => {
      const token = makeToken('student');

      const res = await request(app)
        .post('/api/v1/courses')
        .set('Authorization', `Bearer ${token}`)
        .set('X-Tenant-ID', 'default')
        .send({
          title: 'New Course',
          description: 'Course description',
          level: 'intermediate',
          price: 29.99,
        });

      expect(res.status).toBe(403);
    });
  });
});
