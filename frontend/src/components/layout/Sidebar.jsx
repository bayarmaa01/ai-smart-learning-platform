import React from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import { useSelector } from 'react-redux';
import { useTranslation } from 'react-i18next';
import {
  LayoutDashboard, BookOpen, TrendingUp, Award, CreditCard,
  Bot, Users, BarChart3, Settings, Shield, X, GraduationCap
} from 'lucide-react';

const studentLinks = [
  { to: '/dashboard', icon: LayoutDashboard, labelKey: 'nav.dashboard' },
  { to: '/courses', icon: BookOpen, labelKey: 'nav.courses' },
  { to: '/progress', icon: TrendingUp, labelKey: 'nav.progress' },
  { to: '/certificates', icon: Award, labelKey: 'nav.certificates' },
  { to: '/ai-chat', icon: Bot, labelKey: 'nav.aiChat' },
  { to: '/subscription', icon: CreditCard, labelKey: 'nav.subscription' },
];

const adminLinks = [
  { to: '/admin', icon: Shield, labelKey: 'nav.admin' },
  { to: '/admin/users', icon: Users, labelKey: 'admin.users' },
  { to: '/admin/courses', icon: BookOpen, labelKey: 'admin.courses' },
  { to: '/admin/analytics', icon: BarChart3, labelKey: 'admin.analytics' },
  { to: '/admin/settings', icon: Settings, labelKey: 'admin.settings' },
];

export default function Sidebar({ isOpen, onClose }) {
  const { t } = useTranslation();
  const { user } = useSelector((state) => state.auth);
  const isAdmin = user?.role === 'admin' || user?.role === 'super_admin';

  return (
    <>
      <aside
        className={`fixed top-0 left-0 h-full w-64 bg-slate-900 border-r border-slate-700/50 z-30 transform transition-transform duration-300 flex flex-col ${
          isOpen ? 'translate-x-0' : '-translate-x-full'
        }`}
      >
        <div className="flex items-center justify-between p-5 border-b border-slate-700/50">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 bg-gradient-to-br from-primary-500 to-accent-500 rounded-xl flex items-center justify-center">
              <GraduationCap className="w-5 h-5 text-white" />
            </div>
            <div>
              <span className="text-white font-bold text-lg">EduAI</span>
              <p className="text-xs text-slate-400">Platform</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="lg:hidden p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-700/50 transition-colors"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        <nav className="flex-1 overflow-y-auto p-3 space-y-1">
          <div className="mb-4">
            <p className="px-3 text-xs font-semibold text-slate-500 uppercase tracking-wider mb-2">
              {t('nav.home')}
            </p>
            {studentLinks.map(({ to, icon: Icon, labelKey }) => (
              <NavLink
                key={to}
                to={to}
                end={to === '/dashboard'}
                className={({ isActive }) =>
                  `sidebar-link ${isActive ? 'active' : ''}`
                }
              >
                <Icon className="w-5 h-5 flex-shrink-0" />
                <span className="text-sm">{t(labelKey)}</span>
              </NavLink>
            ))}
          </div>

          {isAdmin && (
            <div>
              <p className="px-3 text-xs font-semibold text-slate-500 uppercase tracking-wider mb-2 mt-4">
                Administration
              </p>
              {adminLinks.map(({ to, icon: Icon, labelKey }) => (
                <NavLink
                  key={to}
                  to={to}
                  end={to === '/admin'}
                  className={({ isActive }) =>
                    `sidebar-link ${isActive ? 'active' : ''}`
                  }
                >
                  <Icon className="w-5 h-5 flex-shrink-0" />
                  <span className="text-sm">{t(labelKey)}</span>
                </NavLink>
              ))}
            </div>
          )}
        </nav>

        <div className="p-4 border-t border-slate-700/50">
          <div className="flex items-center gap-3 p-3 rounded-xl bg-slate-800/50">
            <div className="w-8 h-8 rounded-full bg-gradient-to-br from-primary-500 to-accent-500 flex items-center justify-center text-white text-xs font-bold flex-shrink-0">
              {user?.firstName?.[0]?.toUpperCase() || 'U'}
            </div>
            <div className="min-w-0">
              <p className="text-sm font-medium text-slate-200 truncate">
                {user?.firstName} {user?.lastName}
              </p>
              <p className="text-xs text-slate-400 capitalize">{user?.role}</p>
            </div>
          </div>
        </div>
      </aside>
    </>
  );
}
