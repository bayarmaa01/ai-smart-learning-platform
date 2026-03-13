import React from 'react';
import { Navigate, Outlet, useLocation } from 'react-router-dom';
import { useSelector } from 'react-redux';

export default function ProtectedRoute() {
  const { isAuthenticated, user } = useSelector((state) => state.auth);
  const location = useLocation();

  if (!isAuthenticated) {
    return <Navigate to="/login" state={{ from: location }} replace />;
  }

  // Role-based redirection
  if (user) {
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

    // Prevent instructors from accessing student routes
    if (user.role === 'instructor' && !currentPath.startsWith('/instructor') && !currentPath.startsWith('/profile') && !currentPath.startsWith('/settings')) {
      return <Navigate to="/instructor/dashboard" replace />;
    }

    // Prevent non-admins from accessing admin routes
    if (!['admin', 'super_admin'].includes(user.role) && currentPath.startsWith('/admin')) {
      return <Navigate to="/dashboard" replace />;
    }
  }

  return <Outlet />;
}
