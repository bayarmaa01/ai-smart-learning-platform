const request = require('supertest');
const app = require('../src/server');

describe('AI Endpoints', () => {
  describe('POST /api/v1/ai/tutor', () => {
    it('should return explanation for a topic', async () => {
      const response = await request(app)
        .post('/api/v1/ai/tutor')
        .send({
          question: 'Explain Docker containers'
        })
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveProperty('explanation');
      expect(response.body.data).toHaveProperty('steps');
      expect(response.body.data).toHaveProperty('example');
    });

    it('should return error for missing question', async () => {
      const response = await request(app)
        .post('/api/v1/ai/tutor')
        .send({})
        .expect(400);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toContain('Question is required');
    });
  });

  describe('POST /api/v1/ai/quiz', () => {
    it('should generate quiz questions', async () => {
      const response = await request(app)
        .post('/api/v1/ai/quiz')
        .send({
          topic: 'Kubernetes'
        })
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveProperty('quiz');
      expect(Array.isArray(response.body.data.quiz)).toBe(true);
      expect(response.body.data.quiz).toHaveLength(5);
    });

    it('should return error for missing topic', async () => {
      const response = await request(app)
        .post('/api/v1/ai/quiz')
        .send({})
        .expect(400);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toContain('Topic is required');
    });
  });

  describe('POST /api/v1/ai/explain', () => {
    it('should provide smart explanation', async () => {
      const response = await request(app)
        .post('/api/v1/ai/explain')
        .send({
          topic: 'Redis caching'
        })
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveProperty('explanation');
      expect(response.body.data).toHaveProperty('when_to_use');
      expect(response.body.data).toHaveProperty('example');
    });
  });

  describe('POST /api/v1/ai/debug', () => {
    it('should analyze and fix DevOps errors', async () => {
      const response = await request(app)
        .post('/api/v1/ai/debug')
        .send({
          error: 'CrashLoopBackOff Redis ECONNREFUSED'
        })
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveProperty('root_cause');
      expect(response.body.data).toHaveProperty('fix_steps');
      expect(response.body.data).toHaveProperty('prevention');
    });
  });

  describe('GET /api/v1/ai/health', () => {
    it('should return AI service health status', async () => {
      const response = await request(app)
        .get('/api/v1/ai/health')
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveProperty('ai_service');
      expect(response.body.data.ai_service).toHaveProperty('status');
    });
  });
});
