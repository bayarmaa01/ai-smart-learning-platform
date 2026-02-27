import React from 'react';
import { useTranslation } from 'react-i18next';
import {
  AreaChart, Area, BarChart, Bar, XAxis, YAxis, CartesianGrid,
  Tooltip, ResponsiveContainer, LineChart, Line, Legend
} from 'recharts';

const engagementData = [
  { day: 'Mon', sessions: 1200, completions: 340 },
  { day: 'Tue', sessions: 1800, completions: 520 },
  { day: 'Wed', sessions: 1400, completions: 410 },
  { day: 'Thu', sessions: 2100, completions: 680 },
  { day: 'Fri', sessions: 1900, completions: 590 },
  { day: 'Sat', sessions: 900, completions: 280 },
  { day: 'Sun', sessions: 750, completions: 210 },
];

const topCourses = [
  { name: 'ML A-Z', enrollments: 450 },
  { name: 'React Full Stack', enrollments: 380 },
  { name: 'AWS Architect', enrollments: 290 },
  { name: 'Python DS', enrollments: 610 },
  { name: 'K8s & Docker', enrollments: 220 },
];

export default function AdminAnalytics() {
  const { t } = useTranslation();

  return (
    <div className="space-y-6 animate-slide-up">
      <div>
        <h1 className="text-2xl font-bold text-white">{t('admin.analytics')}</h1>
        <p className="text-slate-400 mt-1">Platform performance metrics</p>
      </div>

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {[
          { label: 'Daily Active Users', value: '2,841', change: '+18%' },
          { label: 'Avg. Session Duration', value: '42 min', change: '+5%' },
          { label: 'Course Completion Rate', value: '68%', change: '+3%' },
          { label: 'AI Chat Sessions', value: '1,204', change: '+32%' },
        ].map(({ label, value, change }) => (
          <div key={label} className="card">
            <p className="text-2xl font-bold text-white mb-1">{value}</p>
            <p className="text-sm text-slate-400">{label}</p>
            <p className="text-xs text-green-400 mt-1">{change} this week</p>
          </div>
        ))}
      </div>

      <div className="card">
        <h2 className="text-lg font-semibold text-white mb-4">Weekly Engagement</h2>
        <ResponsiveContainer width="100%" height={260}>
          <AreaChart data={engagementData}>
            <defs>
              <linearGradient id="colorSessions" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor="#3b82f6" stopOpacity={0.3} />
                <stop offset="95%" stopColor="#3b82f6" stopOpacity={0} />
              </linearGradient>
              <linearGradient id="colorCompletions" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor="#10b981" stopOpacity={0.3} />
                <stop offset="95%" stopColor="#10b981" stopOpacity={0} />
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" stroke="#334155" />
            <XAxis dataKey="day" stroke="#64748b" tick={{ fill: '#94a3b8', fontSize: 12 }} />
            <YAxis stroke="#64748b" tick={{ fill: '#94a3b8', fontSize: 12 }} />
            <Tooltip contentStyle={{ background: '#1e293b', border: '1px solid #334155', borderRadius: '8px', color: '#f1f5f9' }} />
            <Legend formatter={(v) => <span style={{ color: '#94a3b8', fontSize: 12 }}>{v}</span>} />
            <Area type="monotone" dataKey="sessions" name="Sessions" stroke="#3b82f6" strokeWidth={2} fill="url(#colorSessions)" />
            <Area type="monotone" dataKey="completions" name="Completions" stroke="#10b981" strokeWidth={2} fill="url(#colorCompletions)" />
          </AreaChart>
        </ResponsiveContainer>
      </div>

      <div className="card">
        <h2 className="text-lg font-semibold text-white mb-4">Top Courses by Enrollment</h2>
        <ResponsiveContainer width="100%" height={220}>
          <BarChart data={topCourses} layout="vertical">
            <CartesianGrid strokeDasharray="3 3" stroke="#334155" />
            <XAxis type="number" stroke="#64748b" tick={{ fill: '#94a3b8', fontSize: 12 }} />
            <YAxis type="category" dataKey="name" stroke="#64748b" tick={{ fill: '#94a3b8', fontSize: 12 }} width={100} />
            <Tooltip contentStyle={{ background: '#1e293b', border: '1px solid #334155', borderRadius: '8px', color: '#f1f5f9' }} />
            <Bar dataKey="enrollments" fill="#a855f7" radius={[0, 4, 4, 0]} />
          </BarChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}
