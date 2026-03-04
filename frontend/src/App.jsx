import React, { useEffect } from 'react';
import { Routes, Route, Navigate } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import { fetchCurrentUser } from './store/slices/authSlice';

import DashboardLayout from './layouts/DashboardLayout';
import AuthLayout from './layouts/AuthLayout';
import ProtectedRoute from './components/common/ProtectedRoute';
import RoleGuard from './components/common/RoleGuard';
import LoadingScreen from './components/common/LoadingScreen';

import LoginPage from './pages/auth/Login';
import RegisterPage from './pages/auth/Register';
import ForgotPasswordPage from './pages/auth/ForgotPassword';

import StudentDashboard from './pages/student/Dashboard';
import CoursesPage from './pages/student/Courses';
import CourseDetailPage from './pages/student/CourseDetail';
import PlayerPage from './pages/student/Player';
import PlacementTestPage from './pages/student/PlacementTest';
import ProgressPage from './pages/student/Progress';
import CertificatesPage from './pages/student/Certificates';
import SubscriptionPage from './pages/student/Subscription';

import AdminDashboard from './pages/admin/AdminDashboard';
import AdminUsers from './pages/admin/AdminUsers';
import AdminCourses from './pages/admin/AdminCourses';
import AdminAnalytics from './pages/admin/AdminAnalytics';
import AdminSettings from './pages/admin/AdminSettings';

import AIChatPage from './pages/ai/AIChat';
import ProfilePage from './pages/student/Profile';
import SettingsPage from './pages/student/Settings';
import NotFoundPage from './pages/NotFound';

export default function App() {
  const dispatch = useDispatch();
  const { isInitialized } = useSelector((state) => state.auth);

  useEffect(() => {
    const token = localStorage.getItem('accessToken');
    if (token) {
      dispatch(fetchCurrentUser());
    } else {
      dispatch({ type: 'auth/fetchCurrentUser/rejected' });
    }
  }, [dispatch]);

  if (!isInitialized) {
    return <LoadingScreen />;
  }

  return (
    <Routes>
      <Route element={<AuthLayout />}>
        <Route path="/login" element={<LoginPage />} />
        <Route path="/register" element={<RegisterPage />} />
        <Route path="/forgot-password" element={<ForgotPasswordPage />} />
      </Route>

      <Route element={<ProtectedRoute />}>
        <Route element={<DashboardLayout />}>
          <Route path="/dashboard" element={<StudentDashboard />} />
          <Route path="/courses" element={<CoursesPage />} />
          <Route path="/courses/:id" element={<CourseDetailPage />} />
          <Route path="/courses/:id/learn" element={<PlayerPage />} />
          <Route path="/placement-test" element={<PlacementTestPage />} />
          <Route path="/progress" element={<ProgressPage />} />
          <Route path="/certificates" element={<CertificatesPage />} />
          <Route path="/subscription" element={<SubscriptionPage />} />
          <Route path="/ai-chat" element={<AIChatPage />} />
          <Route path="/profile" element={<ProfilePage />} />
          <Route path="/settings" element={<SettingsPage />} />

          <Route element={<RoleGuard roles={['admin', 'super_admin']} />}>
            <Route path="/admin" element={<AdminDashboard />} />
            <Route path="/admin/users" element={<AdminUsers />} />
            <Route path="/admin/courses" element={<AdminCourses />} />
            <Route path="/admin/analytics" element={<AdminAnalytics />} />
            <Route path="/admin/settings" element={<AdminSettings />} />
          </Route>
        </Route>
      </Route>

      <Route path="/" element={<Navigate to="/dashboard" replace />} />
      <Route path="*" element={<NotFoundPage />} />
    </Routes>
  );
}
