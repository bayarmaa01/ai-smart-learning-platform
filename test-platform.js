#!/usr/bin/env node

/**
 * AI Smart Learning Platform - Comprehensive Test Script
 * Tests all major functionality after deployment
 */

const axios = require('axios');
const colors = require('colors');

// Configuration
const BASE_URL = 'http://localhost:5000';
const FRONTEND_URL = 'http://localhost:3000';

// Test utilities
const log = {
  info: (msg) => console.log(`ℹ️  ${msg}`.blue),
  success: (msg) => console.log(`✅ ${msg}`.green),
  error: (msg) => console.log(`❌ ${msg}`.red),
  warning: (msg) => console.log(`⚠️  ${msg}`.yellow),
  step: (msg) => console.log(`🔄 ${msg}`.cyan)
};

const makeRequest = async (method, url, data = null, headers = {}) => {
  try {
    const config = {
      method,
      url: `${BASE_URL}${url}`,
      headers: {
        'Content-Type': 'application/json',
        ...headers
      }
    };
    
    if (data) {
      config.data = data;
    }
    
    const response = await axios(config);
    return { success: true, data: response.data, status: response.status };
  } catch (error) {
    return { 
      success: false, 
      error: error.response?.data || error.message,
      status: error.response?.status || 500
    };
  }
};

// Test functions
const testBackendHealth = async () => {
  log.step('Testing Backend Health...');
  
  const result = await makeRequest('GET', '/health');
  
  if (result.success && result.data.status === 'healthy') {
    log.success('Backend health check passed');
    return true;
  } else {
    log.error(`Backend health failed: ${result.error}`);
    return false;
  }
};

const testDatabaseConnection = async () => {
  log.step('Testing Database Connection...');
  
  const result = await makeRequest('GET', '/api/v1/health');
  
  if (result.success && result.data.status === 'healthy') {
    log.success('Database connection working');
    return true;
  } else {
    log.error(`Database connection failed: ${result.error}`);
    return false;
  }
};

const testAIChat = async () => {
  log.step('Testing AI Chat...');
  
  const result = await makeRequest('POST', '/api/chat', {
    message: 'Hello, how are you?'
  });
  
  if (result.success && result.data.success) {
    log.success('AI chat endpoint working');
    log.info(`AI Response: ${result.data.data.response.substring(0, 100)}...`);
    return true;
  } else {
    log.warning(`AI chat test failed: ${result.error}`);
    log.warning('This might be due to Ollama not running or gemma4:31b not available');
    return false;
  }
};

const testUserRegistration = async () => {
  log.step('Testing User Registration...');
  
  const testUser = {
    email: `test${Date.now()}@example.com`,
    password: 'Test123456',
    name: 'Test User',
    role: 'student'
  };
  
  const result = await makeRequest('POST', '/api/v1/auth/register', testUser);
  
  if (result.success) {
    log.success('User registration working');
    return { success: true, user: testUser };
  } else {
    log.error(`User registration failed: ${result.error}`);
    return { success: false, user: testUser };
  }
};

const testUserLogin = async (user) => {
  log.step('Testing User Login...');
  
  const result = await makeRequest('POST', '/api/v1/auth/login', {
    email: user.email,
    password: user.password
  });
  
  if (result.success && result.data.accessToken) {
    log.success('User login working');
    return { success: true, token: result.data.accessToken };
  } else {
    log.error(`User login failed: ${result.error}`);
    return { success: false, token: null };
  }
};

const testPlacementTests = async (token) => {
  log.step('Testing Placement Tests...');
  
  // Get available tests
  const testsResult = await makeRequest('GET', '/api/v1/placement-tests', null, {
    'Authorization': `Bearer ${token}`
  });
  
  if (!testsResult.success) {
    log.error(`Failed to get placement tests: ${testsResult.error}`);
    return false;
  }
  
  if (testsResult.data.data.length === 0) {
    log.warning('No placement tests found');
    return true; // Not a failure, just no tests
  }
  
  log.success(`Found ${testsResult.data.data.length} placement tests`);
  
  // Try to get first test
  const testId = testsResult.data.data[0].id;
  const testResult = await makeRequest('GET', `/api/v1/placement-tests/${testId}`, null, {
    'Authorization': `Bearer ${token}`
  });
  
  if (testResult.success) {
    log.success('Placement test retrieval working');
    return true;
  } else {
    log.error(`Failed to get placement test: ${testResult.error}`);
    return false;
  }
};

const testCourses = async (token) => {
  log.step('Testing Courses...');
  
  // Get courses
  const coursesResult = await makeRequest('GET', '/api/v1/courses', null, {
    'Authorization': `Bearer ${token}`
  });
  
  if (!coursesResult.success) {
    log.error(`Failed to get courses: ${coursesResult.error}`);
    return false;
  }
  
  log.success(`Found ${coursesResult.data.data?.length || 0} courses`);
  return true;
};

const testCertificates = async (token) => {
  log.step('Testing Certificates...');
  
  // Get user certificates
  const certsResult = await makeRequest('GET', '/api/v1/certificates/my', null, {
    'Authorization': `Bearer ${token}`
  });
  
  if (certsResult.success) {
    log.success('Certificate endpoint working');
    log.info(`Found ${certsResult.data.data?.length || 0} certificates`);
    return true;
  } else {
    log.error(`Certificate endpoint failed: ${certsResult.error}`);
    return false;
  }
};

const testFrontend = async () => {
  log.step('Testing Frontend...');
  
  try {
    const response = await axios.get(FRONTEND_URL, { timeout: 5000 });
    
    if (response.status === 200 && response.data.includes('html')) {
      log.success('Frontend is accessible');
      return true;
    } else {
      log.error('Frontend returned unexpected response');
      return false;
    }
  } catch (error) {
    log.error(`Frontend test failed: ${error.message}`);
    return false;
  }
};

const testOllamaConnection = async () => {
  log.step('Testing Ollama Connection...');
  
  try {
    const response = await axios.get('http://localhost:11434/api/tags', { timeout: 5000 });
    
    if (response.status === 200) {
      const models = response.data.models || [];
      const hasGemma = models.some(m => m.name.includes('gemma4') && m.name.includes('31b'));
      
      if (hasGemma) {
        log.success('Ollama is running with gemma4:31b model');
        return true;
      } else {
        log.warning('Ollama is running but gemma4:31b model not found');
        log.info('Available models:', models.map(m => m.name).join(', '));
        return false;
      }
    } else {
      log.error('Ollama returned unexpected response');
      return false;
    }
  } catch (error) {
    log.error(`Ollama connection failed: ${error.message}`);
    log.warning('Please start Ollama: ollama serve');
    log.warning('And pull model: ollama pull gemma4:31b');
    return false;
  }
};

// Main test runner
const runTests = async () => {
  console.log('🚀 AI Smart Learning Platform - Comprehensive Test Suite'.rainbow.bold);
  console.log('=' .repeat(60).gray);
  
  const results = {
    backend: false,
    database: false,
    ai: false,
    auth: false,
    placement: false,
    courses: false,
    certificates: false,
    frontend: false,
    ollama: false
  };
  
  let token = null;
  
  // Core infrastructure tests
  results.backend = await testBackendHealth();
  results.database = await testDatabaseConnection();
  results.frontend = await testFrontend();
  results.ollama = await testOllamaConnection();
  results.ai = await testAIChat();
  
  // Authentication tests
  const userResult = await testUserRegistration();
  if (userResult.success) {
    const loginResult = await testUserLogin(userResult.user);
    if (loginResult.success) {
      token = loginResult.token;
      results.auth = true;
    }
  }
  
  // Feature tests (require authentication)
  if (token) {
    results.placement = await testPlacementTests(token);
    results.courses = await testCourses(token);
    results.certificates = await testCertificates(token);
  }
  
  // Results summary
  console.log('\n' + '=' .repeat(60).gray);
  console.log('📊 TEST RESULTS SUMMARY'.bold);
  console.log('=' .repeat(60).gray);
  
  const passedTests = Object.values(results).filter(r => r === true).length;
  const totalTests = Object.keys(results).length;
  
  Object.entries(results).forEach(([test, passed]) => {
    const status = passed ? '✅ PASS' : '❌ FAIL';
    const testName = test.charAt(0).toUpperCase() + test.slice(1).padEnd(15);
    console.log(`${testName}: ${status}`);
  });
  
  console.log('\n' + '-'.repeat(60).gray);
  console.log(`Overall: ${passedTests}/${totalTests} tests passed`.bold);
  
  if (passedTests === totalTests) {
    console.log('🎉 ALL TESTS PASSED! Platform is fully operational!'.green.bold);
  } else if (passedTests >= totalTests * 0.8) {
    console.log('⚠️  Most tests passed. Platform mostly operational.'.yellow.bold);
  } else {
    console.log('❌ Many tests failed. Platform needs attention.'.red.bold);
  }
  
  console.log('\n🔧 NEXT STEPS:');
  if (!results.ollama) {
    console.log('  • Start Ollama: ollama serve'.yellow);
    console.log('  • Pull model: ollama pull gemma4:31b'.yellow);
  }
  if (!results.backend) {
    console.log('  • Check backend logs: kubectl logs -n eduai -l app=backend'.yellow);
  }
  if (!results.database) {
    console.log('  • Check database connection and configuration'.yellow);
  }
  if (!results.frontend) {
    console.log('  • Check frontend deployment and port forwarding'.yellow);
  }
  
  console.log('\n🌐 ACCESS URLS:');
  console.log(`  Frontend: ${FRONTEND_URL}`.cyan);
  console.log(`  Backend:  ${BASE_URL}`.cyan);
  console.log(`  AI Chat:  ${FRONTEND_URL}/ai-chat`.cyan);
  
  return passedTests === totalTests;
};

// Run tests if called directly
if (require.main === module) {
  runTests()
    .then(success => {
      process.exit(success ? 0 : 1);
    })
    .catch(error => {
      console.error('Test suite failed:', error);
      process.exit(1);
    });
}

module.exports = { runTests };
