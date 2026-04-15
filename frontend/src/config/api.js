// API Configuration for different environments
const API_CONFIG = {
  development: {
    baseURL: 'http://localhost:4200/api/v1',
    timeout: 30000
  },
  production: {
    baseURL: 'http://backend:5000/api/v1',
    timeout: 30000
  },
  kubernetes: {
    baseURL: 'http://backend:5000/api/v1',
    timeout: 30000
  }
};

// Get current environment
const getEnvironment = () => {
  if (import.meta.env.MODE === 'production') {
    return 'production';
  }
  if (import.meta.env.VITE_ENVIRONMENT === 'kubernetes') {
    return 'kubernetes';
  }
  return 'development';
};

// Get API config for current environment
export const getApiConfig = () => {
  const env = getEnvironment();
  return API_CONFIG[env];
};

// Export base URL for compatibility
export const API_BASE_URL = getApiConfig().baseURL;
