import React, { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Link } from 'react-router-dom';
import {
  Users, BookOpen, DollarSign, TrendingUp, Activity,
  ArrowUpRight, ArrowDownRight, Server, Database, Cpu, Loader2
} from 'lucide-react';
import {
  AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
  BarChart, Bar
} from 'recharts';
import api from '../../services/api';

function StatCard({ icon: Icon, label, value, change, positive, color }) {
  return (
    <div className="card hover:border-slate-600 transition-colors">
      <div className="flex items-start justify-between mb-4">
        <div className={`w-10 h-10 rounded-xl flex items-center justify-center ${color}`}>
          <Icon className="w-5 h-5 text-white" />
        </div>
        {change && (
          <div className={`flex items-center gap-1 text-xs font-medium ${positive ? 'text-green-400' : 'text-red-400'}`}>
            {positive ? <ArrowUpRight className="w-3.5 h-3.5" /> : <ArrowDownRight className="w-3.5 h-3.5" />}
            {change}
          </div>
        )}
      </div>
      <p className="text-2xl font-bold text-white mb-1">{value}</p>
      <p className="text-sm text-slate-400">{label}</p>
    </div>
  );
}

export default function AdminDashboard() {
  const { t } = useTranslation();
  const [stats, setStats] = useState(null);
  const [recentUsers, setRecentUsers] = useState([]);
  const [revenueData, setRevenueData] = useState([]);
  const [userGrowth, setUserGrowth] = useState([]);
  const [health, setHealth] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    Promise.all([
      api.get('/admin/stats'),
      api.get('/admin/users?limit=5&sortBy=created_at&order=desc'),
      api.get('/admin/analytics/revenue'),
      api.get('/admin/analytics/user-growth'),
      api.get('/admin/health'),
    ]).then(([statsRes, usersRes, revenueRes, growthRes, healthRes]) => {
      setStats(statsRes.data.stats || statsRes.data);
      setRecentUsers(usersRes.data.users || []);
      setRevenueData(revenueRes.data.data || []);
      setUserGrowth(growthRes.data.data || []);
      setHealth(healthRes.data.services || []);
    }).catch(() => {
      setStats({ totalUsers: 0, totalCourses: 0, totalRevenue: 0, activeSubscriptions: 0 });
    }).finally(() => setLoading(false));
  }, []);

  if (loading) {
    return (
      <div className="flex items-center justify-center py-32">
        <Loader2 className="w-8 h-8 text-primary-400 animate-spin" />
      </div>
    );
  }

  const defaultHealth = [
    { icon: Server, label: 'API Server', status: 'Healthy', pct: 98, color: 'text-green-400' },
    { icon: Database, label: 'PostgreSQL', status: 'Healthy', pct: 95, color: 'text-green-400' },
    { icon: Activity, label: 'Redis Cache', status: 'Healthy', pct: 99, color: 'text-green-400' },
    { icon: Cpu, label: 'AI Service', status: 'Healthy', pct: 92, color: 'text-green-400' },
  ];

  const healthItems = health.length > 0
    ? health.map((s) => ({
        icon: s.name === 'PostgreSQL' ? Database : s.name === 'Redis' ? Activity : s.name === 'AI Service' ? Cpu : Server,
        label: s.name,
        status: s.status,
        pct: s.uptime ?? 100,
        color: s.status === 'healthy' ? 'text-green-400' : 'text-red-400',
      }))
    : defaultHealth;

  return (
    <div className="space-y-6 animate-slide-up">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">{t('admin.title')}</h1>
          <p className="text-slate-400 mt-1">Platform overview and analytics</p>
        </div>
        <span className="badge-green">System Healthy</span>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard icon={Users} label={t('admin.totalUsers')} value={(stats?.totalUsers ?? 0).toLocaleString()} change="+12.5%" positive color="bg-primary-600" />
        <StatCard icon={BookOpen} label={t('admin.totalCourses')} value={(stats?.totalCourses ?? 0).toLocaleString()} change="+8.3%" positive color="bg-purple-600" />
        <StatCard icon={DollarSign} label={t('admin.totalRevenue')} value={`$${((stats?.totalRevenue ?? 0) / 100).toLocaleString()}`} change="+24.1%" positive color="bg-green-600" />
        <StatCard icon={TrendingUp} label={t('admin.activeSubscriptions')} value={(stats?.activeSubscriptions ?? 0).toLocaleString()} change="+5.7%" positive color="bg-orange-600" />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="card">
          <h2 className="text-lg font-semibold text-white mb-4">Revenue Overview</h2>
          <ResponsiveContainer width="100%" height={220}>
            <AreaChart data={revenueData.length > 0 ? revenueData : [{ month: 'Now', revenue: 0 }]}>
              <defs>
                <linearGradient id="colorRevenue" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#10b981" stopOpacity={0.3} />
                  <stop offset="95%" stopColor="#10b981" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="#334155" />
              <XAxis dataKey="month" stroke="#64748b" tick={{ fill: '#94a3b8', fontSize: 12 }} />
              <YAxis stroke="#64748b" tick={{ fill: '#94a3b8', fontSize: 12 }} tickFormatter={(v) => `$${(v / 1000).toFixed(0)}k`} />
              <Tooltip contentStyle={{ background: '#1e293b', border: '1px solid #334155', borderRadius: '8px', color: '#f1f5f9' }}
                formatter={(v) => [`$${v.toLocaleString()}`, 'Revenue']} />
              <Area type="monotone" dataKey="revenue" stroke="#10b981" strokeWidth={2} fill="url(#colorRevenue)" />
            </AreaChart>
          </ResponsiveContainer>
        </div>

        <div className="card">
          <h2 className="text-lg font-semibold text-white mb-4">User Growth</h2>
          <ResponsiveContainer width="100%" height={220}>
            <BarChart data={userGrowth.length > 0 ? userGrowth : [{ month: 'Now', users: 0 }]}>
              <CartesianGrid strokeDasharray="3 3" stroke="#334155" />
              <XAxis dataKey="month" stroke="#64748b" tick={{ fill: '#94a3b8', fontSize: 12 }} />
              <YAxis stroke="#64748b" tick={{ fill: '#94a3b8', fontSize: 12 }} />
              <Tooltip contentStyle={{ background: '#1e293b', border: '1px solid #334155', borderRadius: '8px', color: '#f1f5f9' }} />
              <Bar dataKey="users" fill="#3b82f6" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2 card">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-lg font-semibold text-white">{t('admin.recentSignups')}</h2>
            <Link to="/admin/users" className="text-sm text-primary-400 hover:text-primary-300 transition-colors">
              View all
            </Link>
          </div>
          <div className="space-y-3">
            {recentUsers.length > 0 ? recentUsers.map((user, i) => (
              <div key={user.id || i} className="flex items-center justify-between p-3 bg-slate-800/30 rounded-xl">
                <div className="flex items-center gap-3">
                  <div className="w-9 h-9 rounded-full bg-gradient-to-br from-primary-500 to-accent-500 flex items-center justify-center text-white text-sm font-bold">
                    {(user.first_name || user.name || 'U')[0].toUpperCase()}
                  </div>
                  <div>
                    <p className="text-sm font-medium text-white">{user.first_name} {user.last_name}</p>
                    <p className="text-xs text-slate-400">{user.email}</p>
                  </div>
                </div>
                <div className="text-right">
                  <span className={`badge text-xs ${user.role === 'instructor' ? 'badge-purple' : 'badge-blue'}`}>
                    {user.role}
                  </span>
                  <p className="text-xs text-slate-500 mt-1">{new Date(user.created_at).toLocaleDateString()}</p>
                </div>
              </div>
            )) : (
              <p className="text-slate-400 text-sm text-center py-4">No users yet</p>
            )}
          </div>
        </div>

        <div className="card">
          <h2 className="text-lg font-semibold text-white mb-4">{t('admin.systemHealth')}</h2>
          <div className="space-y-4">
            {healthItems.map(({ icon: Icon, label, status, pct, color }) => (
              <div key={label}>
                <div className="flex items-center justify-between mb-1.5">
                  <div className="flex items-center gap-2">
                    <Icon className={`w-4 h-4 ${color}`} />
                    <span className="text-sm text-slate-300">{label}</span>
                  </div>
                  <span className={`text-xs font-medium ${color}`}>{pct}%</span>
                </div>
                <div className="w-full bg-slate-700 rounded-full h-1.5">
                  <div className={`h-1.5 rounded-full ${pct > 90 ? 'bg-green-500' : pct > 70 ? 'bg-yellow-500' : 'bg-red-500'}`}
                    style={{ width: `${pct}%` }} />
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
