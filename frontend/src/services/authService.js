import { jwtDecode } from 'jwt-decode';

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4200/api/v1';

export const authService = {
  // Get current user from token
  getCurrentUser() {
    const token = localStorage.getItem('accessToken');
    if (!token) return null;
    
    try {
      const decoded = jwtDecode(token);
      return {
        id: decoded.userId,
        email: decoded.email,
        role: decoded.role,
        firstName: decoded.firstName || 'User',
        lastName: decoded.lastName || 'User'
      };
    } catch (error) {
      return null;
    }
  },

  // Check if user is authenticated
  isAuthenticated() {
    const token = localStorage.getItem('accessToken');
    if (!token) return false;
    
    try {
      const decoded = jwtDecode(token);
      const now = Date.now() / 1000;
      return decoded.exp > now;
    } catch (error) {
      return false;
    }
  },

  // Check if user has specific role
  hasRole(role) {
    const user = this.getCurrentUser();
    return user && user.role === role;
  },

  // Check if user has any of the specified roles
  hasAnyRole(roles) {
    const user = this.getCurrentUser();
    return user && roles.includes(user.role);
  },

  // Logout user
  logout() {
    localStorage.removeItem('accessToken');
    localStorage.removeItem('refreshToken');
    window.location.href = '/login';
  },

  // Refresh token
  async refreshToken() {
    const refreshToken = localStorage.getItem('refreshToken');
    if (!refreshToken) throw new Error('No refresh token');

    const response = await fetch(`${API_URL}/auth/refresh`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ refreshToken }),
    });

    if (!response.ok) {
      throw new Error('Token refresh failed');
    }

    const data = await response.json();
    if (data.success) {
      localStorage.setItem('accessToken', data.data.accessToken);
      return data.data.accessToken;
    } else {
      throw new Error(data.error?.message || 'Token refresh failed');
    }
  }
};
