import React, { createContext, useContext, useState, useEffect } from 'react';
import { useDispatch } from 'react-redux';
import { setUser, fetchCurrentUser } from '../store/slices/authSlice';
import { authService } from '../services/authService';
import api from '../services/api';

const AuthContext = createContext();

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};

export const AuthProvider = ({ children }) => {
  const dispatch = useDispatch();
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [isAuthenticated, setIsAuthenticated] = useState(false);

  useEffect(() => {
    const initializeAuth = async () => {
      try {
        const token = localStorage.getItem('accessToken');
        if (token) {
          // Validate token with backend
          try {
            const response = await api.get('/auth/me');
            console.log('Auth me response:', response.data);
            if (response.data.success) {
              const userData = response.data.data.user;
              setUser(userData);
              setIsAuthenticated(true);
              // Also update Redux store
              dispatch(setUser(userData));
            } else {
              // Invalid response, clear tokens
              localStorage.removeItem('accessToken');
              localStorage.removeItem('refreshToken');
            }
          } catch (error) {
            console.log('Auth me error, clearing tokens:', error.message);
            // Token invalid or expired, clear it
            localStorage.removeItem('accessToken');
            localStorage.removeItem('refreshToken');
          }
        }
      } catch (error) {
        console.error('Failed to restore user session:', error);
        localStorage.removeItem('accessToken');
        localStorage.removeItem('refreshToken');
      } finally {
        setLoading(false);
      }
    };

    initializeAuth();
  }, []);

  const login = async (credentials) => {
    try {
      const response = await api.post('/auth/login', credentials);
      
      if (response.data.success) {
        const { user: userData, accessToken, refreshToken } = response.data.data;
        
        // Store tokens
        localStorage.setItem('accessToken', accessToken);
        localStorage.setItem('refreshToken', refreshToken);
        
        // Update state
        setUser(userData);
        setIsAuthenticated(true);
        // Also update Redux store
        dispatch(setUser(userData));
        
        return { success: true, user: userData };
      } else {
        return { success: false, error: response.data.error };
      }
    } catch (error) {
      return { 
        success: false, 
        error: error.response?.data?.error || { message: 'Login failed' }
      };
    }
  };

  const register = async (userData) => {
    try {
      const response = await api.post('/auth/register', userData);
      
      if (response.data.success) {
        const { user: newUser, accessToken, refreshToken } = response.data.data;
        
        // Store tokens
        localStorage.setItem('accessToken', accessToken);
        localStorage.setItem('refreshToken', refreshToken);
        
        // Update state
        setUser(newUser);
        setIsAuthenticated(true);
        // Also update Redux store
        dispatch(setUser(newUser));
        
        return { success: true, user: newUser };
      } else {
        return { success: false, error: response.data.error };
      }
    } catch (error) {
      return { 
        success: false, 
        error: error.response?.data?.error || { message: 'Registration failed' }
      };
    }
  };

  const logout = () => {
    localStorage.removeItem('accessToken');
    localStorage.removeItem('refreshToken');
    setUser(null);
    setIsAuthenticated(false);
    // Also update Redux store
    dispatch(setUser(null));
  };

  const value = {
    user,
    loading,
    isAuthenticated,
    login,
    register,
    logout,
    setUser,
    setIsAuthenticated
  };

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
};
