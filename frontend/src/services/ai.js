import axios from 'axios';
import toast from 'react-hot-toast';

const aiApi = axios.create({
  baseURL: '/ai',
  timeout: 60000,
  headers: {
    'Content-Type': 'application/json',
  },
  withCredentials: true,
});

aiApi.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('accessToken');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

aiApi.interceptors.response.use(
  (response) => response,
  async (error) => {
    if (!error.response) {
      const message = error.message || 'AI service unavailable. Please try again later.';
      toast.error(message);
      return Promise.reject(error);
    }

    if (error.response?.status >= 500) {
      toast.error('AI service temporarily unavailable. Please try again later.');
      return Promise.reject(error);
    }

    const message = error.response?.data?.detail || error.response?.data?.message || error.message || 'AI service error.';
    toast.error(message);
    return Promise.reject(error);
  }
);

export const aiService = {
  chat: async (message, options = {}) => {
    const response = await aiApi.post('/chat', {
      message,
      ...options
    });
    return response.data;
  },

  getRecommendations: async (userId, courseContent) => {
    const response = await aiApi.post('/recommendations', {
      user_id: userId,
      course_content: courseContent
    });
    return response.data;
  },

  health: async () => {
    const response = await aiApi.get('/health');
    return response.data;
  }
};

export default aiApi;
