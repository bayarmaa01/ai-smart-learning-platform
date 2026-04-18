import React from 'react';
import { Navigate, Outlet, useLocation } from 'react-router-dom';
import { useAuth } from '../../contexts/AuthContext';
import LoadingSpinner from '../LoadingSpinner';

export default function ProtectedRoute() {
  const location = useLocation();
  const { user, loading, isAuthenticated } = useAuth();

  // Show loading spinner while checking authentication
  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <LoadingSpinner size="large" />
      </div>
    );
  }

  // Redirect to login if not authenticated
  if (!isAuthenticated || !user) {
    return <Navigate to="/login" state={{ from: location }} replace />;
  }

  // Role-based redirection
  const currentPath = location.pathname;
  
  // Redirect to appropriate dashboard based on role
  if (currentPath === '/') {
    switch (user.role) {
      case 'instructor':
        return <Navigate to="/instructor/dashboard" replace />;
      case 'admin':
      case 'super_admin':
        return <Navigate to="/admin" replace />;
      case 'student':
      default:
        return <Navigate to="/dashboard" replace />;
    }
  }

  // Prevent students from accessing instructor routes
  if (user.role === 'student' && currentPath.startsWith('/instructor')) {
    return <Navigate to="/dashboard" replace />;
  }

  // Prevent instructors from accessing student routes (allow shared routes)
  const sharedRoutes = ['/profile', '/settings', '/ai-chat'];
  const isSharedRoute = sharedRoutes.some(route => currentPath.startsWith(route));
  
  if (user.role === 'instructor' && !currentPath.startsWith('/instructor') && !isSharedRoute) {
    return <Navigate to="/instructor/dashboard" replace />;
  }

  // Add error boundary for undefined user role
  if (!user || !user.role) {
    return <Navigate to="/login" state={{ from: location }} replace />;
  }

  // Prevent non-admins from accessing admin routes
  if (!['admin', 'super_admin'].includes(user.role) && currentPath.startsWith('/admin')) {
    return <Navigate to="/dashboard" replace />;
  }

  return <Outlet />;
}
