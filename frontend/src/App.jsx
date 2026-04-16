import React, { useState, useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { Toaster } from 'react-hot-toast';

// Components
import Navbar from './components/Navbar';
import Sidebar from './components/Sidebar';
import LoadingSpinner from './components/LoadingSpinner';

// Pages
import StudentDashboard from './pages/student/Dashboard';
import TeacherDashboard from './pages/TeacherDashboard';
import AdminDashboard from './pages/AdminDashboard';
import Login from './pages/Login';
import Register from './pages/Register';
import Courses from './pages/Courses';
import CourseDetail from './pages/CourseDetail';
import Profile from './pages/Profile';

// Services
import { authService } from './services/authService';
import api from './services/api';

// Create a client
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 1,
      refetchOnWindowFocus: false,
    },
  },
});

function App() {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [sidebarOpen, setSidebarOpen] = useState(false);

  useEffect(() => {
    // Check authentication status on mount
    const token = localStorage.getItem('accessToken');
    if (token) {
      try {
        const userData = authService.getCurrentUser();
        setUser(userData);
      } catch (error) {
        console.error('Failed to restore user session:', error);
        localStorage.removeItem('accessToken');
      }
    }
    setLoading(false);
  }, []);

  const handleLogout = () => {
    authService.logout();
    setUser(null);
  };

  const ProtectedRoute = ({ children }) => {
    if (!user) {
      return <Navigate to="/login" replace />;
    }
    return children;
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <LoadingSpinner size="large" />
      </div>
    );
  }

  return (
    <QueryClientProvider client={queryClient}>
      <Router>
        <div className="min-h-screen bg-gray-50">
          <Navbar user={user} onLogout={handleLogout} onToggleSidebar={() => setSidebarOpen(!sidebarOpen)} />
          
          <div className="flex">
            <Sidebar isOpen={sidebarOpen} userRole={user?.role} />
            
            <main className="flex-1">
              <Routes>
                <Route path="/login" element={<Login setUser={setUser} />} />
                <Route path="/register" element={<Register setUser={setUser} />} />
                
                <Route path="/" element={<Navigate to="/dashboard" replace />} />
                
                <Route path="/dashboard" element={
                  <ProtectedRoute>
                    <StudentDashboard user={user} />
                  </ProtectedRoute>
                } />
                
                <Route path="/teacher" element={
                  <ProtectedRoute>
                    <TeacherDashboard user={user} />
                  </ProtectedRoute>
                } />
                
                <Route path="/admin" element={
                  <ProtectedRoute>
                    <AdminDashboard user={user} />
                  </ProtectedRoute>
                } />
                
                <Route path="/courses" element={
                  <ProtectedRoute>
                    <Courses user={user} />
                  </ProtectedRoute>
                } />
                
                <Route path="/courses/:id" element={
                  <ProtectedRoute>
                    <CourseDetail user={user} />
                  </ProtectedRoute>
                } />
                
                <Route path="/profile" element={
                  <ProtectedRoute>
                    <Profile user={user} />
                  </ProtectedRoute>
                } />
              </Routes>
            </main>
          </div>
        </div>
        
        <Toaster
          position="top-right"
          toastOptions={{
            duration: 4000,
            style: {
              background: '#363636',
              color: '#fff',
            },
          }}
        />
      </Router>
    </QueryClientProvider>
  );
}

export default App;
