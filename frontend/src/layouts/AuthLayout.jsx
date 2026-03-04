import React from 'react';
import { Outlet, Navigate } from 'react-router-dom';
import { useSelector } from 'react-redux';
import LanguageSwitcher from '../components/common/LanguageSwitcher';

export default function AuthLayout() {
  const { isAuthenticated } = useSelector((state) => state.auth);

  if (isAuthenticated) {
    return <Navigate to="/dashboard" replace />;
  }

  return (
    <div className="min-h-screen bg-slate-950 flex">
      <div className="hidden lg:flex lg:w-1/2 relative overflow-hidden">
        <div className="absolute inset-0 bg-gradient-to-br from-primary-900 via-slate-900 to-accent-900" />
        <div className="absolute inset-0 opacity-20"
          style={{
            backgroundImage: `radial-gradient(circle at 25% 25%, #3b82f6 0%, transparent 50%),
                              radial-gradient(circle at 75% 75%, #a855f7 0%, transparent 50%)`,
          }}
        />
        <div className="relative z-10 flex flex-col justify-center px-12 text-white">
          <div className="mb-8">
            <div className="flex items-center gap-3 mb-6">
              <div className="w-12 h-12 bg-primary-500 rounded-xl flex items-center justify-center">
                <svg className="w-7 h-7 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                    d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
                </svg>
              </div>
              <span className="text-2xl font-bold">EduAI Platform</span>
            </div>
            <h1 className="text-4xl font-bold leading-tight mb-4">
              AI-Powered Learning<br />
              <span className="text-primary-400">for Everyone</span>
            </h1>
            <p className="text-slate-300 text-lg leading-relaxed">
              Learn smarter with personalized AI recommendations, multilingual support, and world-class courses.
            </p>
          </div>

          <div className="grid grid-cols-2 gap-4">
            {[
              { icon: '🎓', label: '10,000+ Courses' },
              { icon: '🤖', label: 'AI Tutor' },
              { icon: '🌐', label: 'Multilingual' },
              { icon: '📜', label: 'Certificates' },
            ].map((item) => (
              <div key={item.label} className="glass-card p-4 flex items-center gap-3">
                <span className="text-2xl">{item.icon}</span>
                <span className="text-sm font-medium text-slate-200">{item.label}</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      <div className="flex-1 flex flex-col justify-center items-center p-8">
        <div className="absolute top-4 right-4">
          <LanguageSwitcher />
        </div>
        <div className="w-full max-w-md">
          <Outlet />
        </div>
      </div>
    </div>
  );
}
