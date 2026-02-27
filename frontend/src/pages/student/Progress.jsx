import React from 'react';
import { useTranslation } from 'react-i18next';
import { TrendingUp, BookOpen, Clock, Award, Target } from 'lucide-react';
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
  LineChart, Line, PieChart, Pie, Cell, Legend
} from 'recharts';

const monthlyData = [
  { month: 'Sep', hours: 12, courses: 2 }, { month: 'Oct', hours: 18, courses: 3 },
  { month: 'Nov', hours: 8, courses: 1 }, { month: 'Dec', hours: 22, courses: 4 },
  { month: 'Jan', hours: 15, courses: 2 }, { month: 'Feb', hours: 28, courses: 5 },
];

const skillData = [
  { name: 'Python', value: 85 }, { name: 'ML/AI', value: 70 },
  { name: 'React', value: 75 }, { name: 'DevOps', value: 60 },
  { name: 'SQL', value: 80 },
];

const categoryData = [
  { name: 'Programming', value: 40, color: '#3b82f6' },
  { name: 'AI/ML', value: 30, color: '#a855f7' },
  { name: 'DevOps', value: 20, color: '#10b981' },
  { name: 'Design', value: 10, color: '#f59e0b' },
];

export default function ProgressPage() {
  const { t } = useTranslation();

  return (
    <div className="space-y-6 animate-slide-up">
      <div>
        <h1 className="text-2xl font-bold text-white">{t('nav.progress')}</h1>
        <p className="text-slate-400 mt-1">Track your learning journey</p>
      </div>

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {[
          { icon: BookOpen, label: 'Courses Completed', value: '8', color: 'bg-primary-600' },
          { icon: Clock, label: 'Hours Learned', value: '103h', color: 'bg-purple-600' },
          { icon: Award, label: 'Certificates', value: '3', color: 'bg-green-600' },
          { icon: Target, label: 'Avg. Score', value: '87%', color: 'bg-orange-600' },
        ].map(({ icon: Icon, label, value, color }) => (
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
      </div>

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
    </div>
  );
}
