import React, { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { TrendingUp, BookOpen, Clock, Award, Target, Loader2 } from 'lucide-react';
import api from '../../services/api';
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
  PieChart, Pie, Cell, Legend
} from 'recharts';

const COLORS = ['#3b82f6', '#a855f7', '#10b981', '#f59e0b', '#ef4444'];

export default function ProgressPage() {
  const { t } = useTranslation();
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.get('/users/progress').then((res) => {
      setData(res.data);
    }).catch(() => {
      setData({ fallback: true });
    }).finally(() => setLoading(false));
  }, []);

  const monthlyData = data?.monthly || [
    { month: 'Sep', hours: 0 }, { month: 'Oct', hours: 0 }, { month: 'Nov', hours: 0 },
    { month: 'Dec', hours: 0 }, { month: 'Jan', hours: 0 }, { month: 'Feb', hours: 0 },
  ];

  const categoryData = (data?.categories || []).map((c, i) => ({
    ...c,
    color: COLORS[i % COLORS.length],
  }));

  const skillData = data?.skills || [];

  const stats = [
    { icon: BookOpen, label: 'Courses Completed', value: data?.completedCourses ?? 0, color: 'bg-primary-600' },
    { icon: Clock, label: 'Hours Learned', value: `${Math.round(data?.totalHours ?? 0)}h`, color: 'bg-purple-600' },
    { icon: Award, label: 'Certificates', value: data?.certificates ?? 0, color: 'bg-green-600' },
    { icon: Target, label: 'Avg. Score', value: `${Math.round(data?.avgScore ?? 0)}%`, color: 'bg-orange-600' },
  ];

  if (loading) {
    return (
      <div className="flex items-center justify-center py-32">
        <Loader2 className="w-8 h-8 text-primary-400 animate-spin" />
      </div>
    );
  }

  return (
    <div className="space-y-6 animate-slide-up">
      <div>
        <h1 className="text-2xl font-bold text-white">{t('nav.progress')}</h1>
        <p className="text-slate-400 mt-1">Track your learning journey</p>
      </div>

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {stats.map(({ icon: Icon, label, value, color }) => (
          <div key={label} className="card">
            <div className={`w-10 h-10 ${color} rounded-xl flex items-center justify-center mb-3`}>
              <Icon className="w-5 h-5 text-white" />
            </div>
            <p className="text-2xl font-bold text-white">{value}</p>
            <p className="text-sm text-slate-400">{label}</p>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="card">
          <h2 className="text-lg font-semibold text-white mb-4">Monthly Learning Hours</h2>
          <ResponsiveContainer width="100%" height={220}>
            <BarChart data={monthlyData}>
              <CartesianGrid strokeDasharray="3 3" stroke="#334155" />
              <XAxis dataKey="month" stroke="#64748b" tick={{ fill: '#94a3b8', fontSize: 12 }} />
              <YAxis stroke="#64748b" tick={{ fill: '#94a3b8', fontSize: 12 }} />
              <Tooltip contentStyle={{ background: '#1e293b', border: '1px solid #334155', borderRadius: '8px', color: '#f1f5f9' }} />
              <Bar dataKey="hours" fill="#3b82f6" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>

        {categoryData.length > 0 ? (
          <div className="card">
            <h2 className="text-lg font-semibold text-white mb-4">Learning by Category</h2>
            <ResponsiveContainer width="100%" height={220}>
              <PieChart>
                <Pie data={categoryData} cx="50%" cy="50%" innerRadius={60} outerRadius={90} paddingAngle={3} dataKey="value">
                  {categoryData.map((entry, i) => <Cell key={i} fill={entry.color} />)}
                </Pie>
                <Legend formatter={(value) => <span style={{ color: '#94a3b8', fontSize: 12 }}>{value}</span>} />
                <Tooltip contentStyle={{ background: '#1e293b', border: '1px solid #334155', borderRadius: '8px', color: '#f1f5f9' }} />
              </PieChart>
            </ResponsiveContainer>
          </div>
        ) : (
          <div className="card flex items-center justify-center">
            <div className="text-center">
              <TrendingUp className="w-10 h-10 text-slate-600 mx-auto mb-3" />
              <p className="text-slate-400 text-sm">Complete courses to see category breakdown</p>
            </div>
          </div>
        )}
      </div>

      {skillData.length > 0 && (
        <div className="card">
          <h2 className="text-lg font-semibold text-white mb-6">Skill Progress</h2>
          <div className="space-y-4">
            {skillData.map(({ name, value }) => (
              <div key={name}>
                <div className="flex items-center justify-between mb-1.5">
                  <span className="text-sm font-medium text-slate-300">{name}</span>
                  <span className="text-sm text-slate-400">{value}%</span>
                </div>
                <div className="w-full bg-slate-700 rounded-full h-2">
                  <div
                    className="bg-gradient-to-r from-primary-500 to-accent-500 h-2 rounded-full transition-all duration-700"
                    style={{ width: `${value}%` }}
                  />
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {data?.enrolledCourses?.length > 0 && (
        <div className="card">
          <h2 className="text-lg font-semibold text-white mb-4">Course Progress</h2>
          <div className="space-y-4">
            {data.enrolledCourses.map((course) => (
              <div key={course.id}>
                <div className="flex items-center justify-between mb-1.5">
                  <span className="text-sm font-medium text-slate-300 truncate max-w-xs">{course.title}</span>
                  <span className="text-sm text-slate-400 ml-2">{Math.round(course.progress_percentage ?? 0)}%</span>
                </div>
                <div className="w-full bg-slate-700 rounded-full h-2">
                  <div
                    className="bg-gradient-to-r from-primary-500 to-accent-500 h-2 rounded-full"
                    style={{ width: `${Math.min(100, course.progress_percentage ?? 0)}%` }}
                  />
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
