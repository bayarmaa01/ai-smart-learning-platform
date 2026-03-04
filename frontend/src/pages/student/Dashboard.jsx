import React, { useEffect, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { useTranslation } from 'react-i18next';
import { Link } from 'react-router-dom';
import { fetchMyCourses } from '../../store/slices/courseSlice';
import api from '../../services/api';
import {
  BookOpen, Clock, Award, TrendingUp, Play, ChevronRight,
  Flame, Star, Target, Zap
} from 'lucide-react';
import {
  AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer
} from 'recharts';

function StatCard({ icon: Icon, label, value, color, trend }) {
  return (
    <div className="card hover:border-slate-600 transition-colors">
      <div className="flex items-start justify-between mb-4">
        <div className={`w-10 h-10 rounded-xl flex items-center justify-center ${color}`}>
          <Icon className="w-5 h-5 text-white" />
        </div>
        {trend != null && (
          <span className="badge-green text-xs">+{trend}%</span>
        )}
      </div>
      <p className="text-2xl font-bold text-white mb-1">{value}</p>
      <p className="text-sm text-slate-400">{label}</p>
    </div>
  );
}

function CourseProgressCard({ course }) {
  const progress = course.progress_percentage ?? course.progress ?? 0;
  return (
    <div className="flex items-center gap-4 p-4 bg-slate-800/30 rounded-xl hover:bg-slate-800/50 transition-colors group">
      <div className="w-14 h-14 rounded-xl bg-gradient-to-br from-primary-500/20 to-accent-500/20 border border-primary-500/20 flex items-center justify-center flex-shrink-0">
        <BookOpen className="w-6 h-6 text-primary-400" />
      </div>
      <div className="flex-1 min-w-0">
        <p className="text-sm font-semibold text-white truncate">{course.title}</p>
        <p className="text-xs text-slate-400 mt-0.5">{course.instructor_name || course.instructor}</p>
        <div className="mt-2 flex items-center gap-2">
          <div className="flex-1 bg-slate-700 rounded-full h-1.5">
            <div
              className="bg-gradient-to-r from-primary-500 to-accent-500 h-1.5 rounded-full transition-all duration-500"
              style={{ width: `${Math.min(100, Math.max(0, progress))}%` }}
            />
          </div>
          <span className="text-xs text-slate-400 flex-shrink-0">{Math.round(progress)}%</span>
        </div>
      </div>
      <Link
        to={`/courses/${course.id}/learn`}
        className="p-2 rounded-lg bg-primary-600/20 text-primary-400 hover:bg-primary-600/40 transition-colors opacity-0 group-hover:opacity-100"
      >
        <Play className="w-4 h-4" />
      </Link>
    </div>
  );
}

export default function StudentDashboard() {
  const { t } = useTranslation();
  const dispatch = useDispatch();
  const { user } = useSelector((state) => state.auth);
  const { myCourses } = useSelector((state) => state.courses);
  const [stats, setStats] = useState(null);
  const [weeklyData, setWeeklyData] = useState([
    { day: 'Mon', hours: 0 }, { day: 'Tue', hours: 0 }, { day: 'Wed', hours: 0 },
    { day: 'Thu', hours: 0 }, { day: 'Fri', hours: 0 }, { day: 'Sat', hours: 0 },
    { day: 'Sun', hours: 0 },
  ]);

  useEffect(() => {
    dispatch(fetchMyCourses());
    api.get('/users/stats').then((res) => {
      setStats(res.data.stats);
    }).catch(() => null);
    api.get('/users/activity/weekly').then((res) => {
      if (res.data.weekly?.length) setWeeklyData(res.data.weekly);
    }).catch(() => null);
  }, [dispatch]);

  const enrolledCount = stats?.enrolledCourses ?? myCourses.length;
  const certificateCount = stats?.certificates ?? 0;
  const totalHours = stats?.totalHours ?? 0;
  const completionRate = stats?.completionRate ?? 0;
  const streak = stats?.streak ?? 0;
  const weeklyGoalHours = stats?.weeklyGoalHours ?? 10;
  const weeklyCompletedHours = stats?.weeklyCompletedHours ?? 0;
  const weeklyGoalPct = weeklyGoalHours > 0 ? Math.min(100, Math.round((weeklyCompletedHours / weeklyGoalHours) * 100)) : 0;
  const points = stats?.points ?? 0;

  const statCards = [
    { icon: BookOpen, label: t('dashboard.enrolledCourses'), value: enrolledCount, color: 'bg-primary-600', trend: null },
    { icon: Award, label: t('dashboard.certificates'), value: certificateCount, color: 'bg-green-600', trend: null },
    { icon: Clock, label: t('dashboard.totalHours'), value: `${Math.round(totalHours)}h`, color: 'bg-purple-600', trend: null },
    { icon: TrendingUp, label: t('dashboard.completionRate'), value: `${Math.round(completionRate)}%`, color: 'bg-orange-600', trend: null },
  ];

  const inProgressCourses = myCourses.filter((c) => {
    const p = c.progress_percentage ?? c.progress ?? 0;
    return p > 0 && p < 100;
  }).slice(0, 4);

  const displayCourses = inProgressCourses.length > 0 ? inProgressCourses : myCourses.slice(0, 4);

  return (
    <div className="space-y-6 animate-slide-up">
      <div className="flex items-start justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">
            {t('dashboard.welcome', { name: user?.firstName || 'Student' })}
          </h1>
          <p className="text-slate-400 mt-1">{t('dashboard.subtitle')}</p>
        </div>
        {streak > 0 && (
          <div className="flex items-center gap-2 px-4 py-2 bg-orange-500/10 border border-orange-500/20 rounded-xl">
            <Flame className="w-5 h-5 text-orange-400" />
            <span className="text-orange-300 font-semibold text-sm">{streak} {t('dashboard.streak')}</span>
          </div>
        )}
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {statCards.map((stat) => (
          <StatCard key={stat.label} {...stat} />
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2 card">
          <div className="flex items-center justify-between mb-6">
            <h2 className="text-lg font-semibold text-white">{t('dashboard.progressOverview')}</h2>
            <span className="badge-blue">This Week</span>
          </div>
          <ResponsiveContainer width="100%" height={200}>
            <AreaChart data={weeklyData}>
              <defs>
                <linearGradient id="colorHours" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#3b82f6" stopOpacity={0.3} />
                  <stop offset="95%" stopColor="#3b82f6" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="#334155" />
              <XAxis dataKey="day" stroke="#64748b" tick={{ fill: '#94a3b8', fontSize: 12 }} />
              <YAxis stroke="#64748b" tick={{ fill: '#94a3b8', fontSize: 12 }} />
              <Tooltip
                contentStyle={{ background: '#1e293b', border: '1px solid #334155', borderRadius: '8px', color: '#f1f5f9' }}
              />
              <Area type="monotone" dataKey="hours" stroke="#3b82f6" strokeWidth={2} fill="url(#colorHours)" />
            </AreaChart>
          </ResponsiveContainer>
        </div>

        <div className="card">
          <h2 className="text-lg font-semibold text-white mb-4">{t('dashboard.weeklyGoal')}</h2>
          <div className="flex items-center justify-center mb-4">
            <div className="relative w-32 h-32">
              <svg className="w-32 h-32 -rotate-90" viewBox="0 0 120 120">
                <circle cx="60" cy="60" r="50" fill="none" stroke="#334155" strokeWidth="10" />
                <circle
                  cx="60" cy="60" r="50" fill="none" stroke="#3b82f6" strokeWidth="10"
                  strokeDasharray={`${2 * Math.PI * 50 * (weeklyGoalPct / 100)} ${2 * Math.PI * 50}`}
                  strokeLinecap="round"
                />
              </svg>
              <div className="absolute inset-0 flex flex-col items-center justify-center">
                <span className="text-2xl font-bold text-white">{weeklyGoalPct}%</span>
                <span className="text-xs text-slate-400">of {weeklyGoalHours}h</span>
              </div>
            </div>
          </div>
          <div className="space-y-3">
            {[
              { icon: Target, label: 'Goal', value: `${weeklyGoalHours} hours/week`, color: 'text-primary-400' },
              { icon: Zap, label: 'Completed', value: `${weeklyCompletedHours.toFixed(1)} hours`, color: 'text-green-400' },
              { icon: Star, label: 'Points', value: `${points.toLocaleString()} pts`, color: 'text-yellow-400' },
            ].map(({ icon: Icon, label, value, color }) => (
              <div key={label} className="flex items-center justify-between p-2 rounded-lg bg-slate-800/30">
                <div className="flex items-center gap-2">
                  <Icon className={`w-4 h-4 ${color}`} />
                  <span className="text-sm text-slate-400">{label}</span>
                </div>
                <span className="text-sm font-medium text-white">{value}</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      <div className="card">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-semibold text-white">{t('dashboard.continueLearning')}</h2>
          <Link to="/courses" className="text-sm text-primary-400 hover:text-primary-300 flex items-center gap-1 transition-colors">
            {t('dashboard.viewAll')} <ChevronRight className="w-4 h-4" />
          </Link>
        </div>
        {displayCourses.length > 0 ? (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            {displayCourses.map((course) => (
              <CourseProgressCard key={course.id} course={course} />
            ))}
          </div>
        ) : (
          <div className="text-center py-8">
            <BookOpen className="w-10 h-10 text-slate-600 mx-auto mb-3" />
            <p className="text-slate-400 text-sm">No courses yet.</p>
            <Link to="/courses" className="btn-primary text-sm mt-4 inline-block">Browse Courses</Link>
          </div>
        )}
      </div>
    </div>
  );
}
