import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate } from 'k6/metrics';

// Configuration
export const options = {
  stages: [
    { duration: '2m', target: 10 }, // Warm up
    { duration: '5m', target: 50 }, // Normal load
    { duration: '10m', target: 100 }, // Peak load
    { duration: '5m', target: 200 }, // Stress test
    { duration: '2m', target: 0 }, // Cool down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests under 500ms
    http_req_failed: ['rate<0.1'], // Error rate under 10%
    http_reqs: ['rate>10'], // Minimum 10 requests per second
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:80';

// Custom metrics
const errorRate = new Rate('errors');

// Test data
const testUsers = [
  { email: 'test1@example.com', password: 'password123' },
  { email: 'test2@example.com', password: 'password123' },
  { email: 'test3@example.com', password: 'password123' },
];

// Helper functions
function getRandomUser() {
  return testUsers[Math.floor(Math.random() * testUsers.length)];
}

function generateCourseData() {
  return {
    title: `Test Course ${Math.random().toString(36).substring(7)}`,
    description: 'Performance test course',
    category: 'programming',
    difficulty: 'beginner',
    estimated_duration: 30,
  };
}

// Main test scenarios
export default function () {
  // Scenario 1: Health checks
  group('Health Checks', function () {
    const responses = http.batch([
      ['GET', `${BASE_URL}/health`],
      ['GET', `${BASE_URL}/api/health`],
      ['GET', `${BASE_URL}/ai/health`],
    ]);
    
    check(responses[0], {
      'frontend health check': (r) => r.status === 200,
    });
    
    check(responses[1], {
      'backend health check': (r) => r.status === 200,
    });
    
    check(responses[2], {
      'ai service health check': (r) => r.status === 200,
    });
  });

  // Scenario 2: User authentication
  group('User Authentication', function () {
    const user = getRandomUser();
    
    const loginResponse = http.post(`${BASE_URL}/api/auth/login`, JSON.stringify({
      email: user.email,
      password: user.password,
    }), {
      headers: { 'Content-Type': 'application/json' },
    });
    
    check(loginResponse, {
      'login successful': (r) => r.status === 200,
      'login response time < 500ms': (r) => r.timings.duration < 500,
      'login token received': (r) => JSON.parse(r.body).token !== undefined,
    });
    
    // Store token for subsequent requests
    const token = JSON.parse(loginResponse.body).token;
    
    // Scenario 3: API endpoints
    group('API Endpoints', function () {
      const headers = {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      };
      
      // Get user profile
      const profileResponse = http.get(`${BASE_URL}/api/user/profile`, { headers });
      check(profileResponse, {
        'profile retrieved': (r) => r.status === 200,
        'profile response time < 300ms': (r) => r.timings.duration < 300,
      });
      
      // Get courses
      const coursesResponse = http.get(`${BASE_URL}/api/courses`, { headers });
      check(coursesResponse, {
        'courses retrieved': (r) => r.status === 200,
        'courses response time < 500ms': (r) => r.timings.duration < 500,
      });
      
      // Create course (POST)
      const courseData = generateCourseData();
      const createCourseResponse = http.post(`${BASE_URL}/api/courses`, JSON.stringify(courseData), { headers });
      check(createCourseResponse, {
        'course created': (r) => r.status === 201,
        'course creation time < 1000ms': (r) => r.timings.duration < 1000,
      });
    });
  });

  // Scenario 4: AI Service
  group('AI Service', function () {
    const aiRequest = {
      prompt: 'Explain machine learning in simple terms',
      model: 'gpt-3.5-turbo',
      max_tokens: 150,
    };
    
    const aiResponse = http.post(`${BASE_URL}/ai/generate`, JSON.stringify(aiRequest), {
      headers: { 'Content-Type': 'application/json' },
    });
    
    check(aiResponse, {
      'ai service responds': (r) => r.status === 200,
      'ai response time < 5000ms': (r) => r.timings.duration < 5000,
      'ai response contains text': (r) => JSON.parse(r.body).response !== undefined,
    });
  });

  // Scenario 5: Frontend assets
  group('Frontend Assets', function () {
    const assets = [
      '/',
      '/static/js/main.js',
      '/static/css/main.css',
      '/favicon.ico',
    ];
    
    const responses = http.batch(assets.map(asset => ['GET', `${BASE_URL}${asset}`]));
    
    responses.forEach((response, index) => {
      const asset = assets[index];
      check(response, {
        [`${asset} loads successfully`]: (r) => r.status < 400,
        [`${asset} loads fast`]: (r) => r.timings.duration < 1000,
      });
    });
  });

  // Scenario 6: Concurrent users
  group('Concurrent Users', function () {
    // Simulate multiple users accessing different endpoints
    const concurrentRequests = Array(20).fill().map((_, i) => [
      'GET',
      `${BASE_URL}/api/courses?page=${i % 10}`,
    ]);
    
    const responses = http.batch(concurrentRequests);
    
    responses.forEach((response, index) => {
      check(response, {
        [`concurrent request ${index} successful`]: (r) => r.status === 200,
        [`concurrent request ${index} response time < 1000ms`]: (r) => r.timings.duration < 1000,
      });
    });
  });

  // Cool down period
  group('Cool Down', function () {
    sleep(2);
    
    // Final health check
    const finalHealthCheck = http.get(`${BASE_URL}/health`);
    check(finalHealthCheck, {
      'system recovered after load': (r) => r.status === 200,
    });
  });
}
