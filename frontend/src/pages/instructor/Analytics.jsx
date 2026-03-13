import React, { useState } from 'react';
import { useTranslation } from 'react-i18next';
import {
  BarChart3,
  TrendingUp,
  Users,
  DollarSign,
  Clock,
  Eye,
  Download,
  Calendar,
  Filter
} from 'lucide-react';

export default function InstructorAnalytics() {
  const { t } = useTranslation();
  const [timeRange, setTimeRange] = useState('30d');

  const stats = [
    {
      title: t('instructor.totalRevenue', { defaultValue: 'Total Revenue' }),
      value: '$24,580',
      change: '+12% from last month',
      icon: DollarSign,
      color: 'bg-green-500',
    },
    {
      title: t('instructor.totalStudents', { defaultValue: 'Total Students' }),
      value: '1,248',
      change: '+156 this month',
      icon: Users,
      color: 'bg-blue-500',
    },
    {
      title: t('instructor.courseCompletion', { defaultValue: 'Course Completion' }),
      value: '87%',
      change: '+5% from last month',
      icon: TrendingUp,
      color: 'bg-purple-500',
    },
    {
      title: t('instructor.avgWatchTime', { defaultValue: 'Avg. Watch Time' }),
      value: '4.2h',
      change: '+0.3h from last month',
      icon: Clock,
      color: 'bg-yellow-500',
    },
  ];

  const revenueData = [
    { month: 'Jan', revenue: 18000 },
    { month: 'Feb', revenue: 22000 },
    { month: 'Mar', revenue: 24580 },
  ];

  const enrollmentData = [
    { month: 'Jan', students: 890 },
    { month: 'Feb', students: 1092 },
    { month: 'Mar', students: 1248 },
  ];

  const topCourses = [
    {
      title: 'Advanced React Development',
      students: 342,
      revenue: '$8,420',
      completion: 78,
      rating: 4.8,
    },
    {
      title: 'Node.js Masterclass',
      students: 256,
      revenue: '$6,340',
      completion: 92,
      rating: 4.9,
    },
    {
      title: 'Python for Beginners',
      students: 189,
      revenue: '$4,210',
      completion: 65,
      rating: 4.7,
    },
  ];

  return (
    <div className="animate-fade-in">
      <div className="flex items-center justify-between mb-8">
        <div>
          <h1 className="text-3xl font-bold text-white mb-2">
            {t('instructor.analytics', { defaultValue: 'Analytics' })}
          </h1>
          <p className="text-slate-400">
            {t('instructor.analyticsDesc', { defaultValue: 'Track your course performance and student engagement' })}
          </p>
        </div>
        <div className="flex items-center gap-3">
          <select
            value={timeRange}
            onChange={(e) => setTimeRange(e.target.value)}
            className="px-4 py-2 bg-slate-800/50 border border-slate-600/50 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-transparent"
          >
            <option value="7d">{t('instructor.last7Days', { defaultValue: 'Last 7 days' })}</option>
            <option value="30d">{t('instructor.last30Days', { defaultValue: 'Last 30 days' })}</option>
            <option value="90d">{t('instructor.last90Days', { defaultValue: 'Last 90 days' })}</option>
            <option value="1y">{t('instructor.lastYear', { defaultValue: 'Last year' })}</option>
          </select>
          <button className="btn-primary flex items-center gap-2">
            <Download className="w-4 h-4" />
            {t('instructor.exportReport', { defaultValue: 'Export Report' })}
          </button>
        </div>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        {stats.map((stat, index) => (
          <div key={index} className="card">
            <div className="flex items-center justify-between mb-4">
              <div className={`w-12 h-12 ${stat.color} rounded-lg flex items-center justify-center`}>
                <stat.icon className="w-6 h-6 text-white" />
              </div>
              <span className="text-sm text-green-400 font-medium">{stat.change}</span>
            </div>
            <h3 className="text-2xl font-bold text-white mb-1">{stat.value}</h3>
            <p className="text-sm text-slate-400">{stat.title}</p>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
        {/* Revenue Chart */}
        <div className="card">
          <div className="flex items-center justify-between mb-6">
            <h2 className="text-xl font-bold text-white">
              {t('instructor.revenueTrend', { defaultValue: 'Revenue Trend' })}
            </h2>
            <button className="btn-ghost p-2">
              <Eye className="w-4 h-4" />
            </button>
          </div>
          
          <div className="space-y-4">
            {revenueData.map((data, index) => (
              <div key={index} className="flex items-center justify-between">
                <span className="text-slate-400">{data.month}</span>
                <div className="flex items-center gap-3">
                  <div className="w-32 bg-slate-700 rounded-full h-2">
                    <div
                      className="bg-green-500 h-2 rounded-full"
                      style={{ width: `${(data.revenue / 25000) * 100}%` }}
                    ></div>
                  </div>
                  <span className="text-green-400 font-medium">${data.revenue.toLocaleString()}</span>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Enrollment Chart */}
        <div className="card">
          <div className="flex items-center justify-between mb-6">
            <h2 className="text-xl font-bold text-white">
              {t('instructor.enrollmentTrend', { defaultValue: 'Enrollment Trend' })}
            </h2>
            <button className="btn-ghost p-2">
              <Eye className="w-4 h-4" />
            </button>
          </div>
          
          <div className="space-y-4">
            {enrollmentData.map((data, index) => (
              <div key={index} className="flex items-center justify-between">
                <span className="text-slate-400">{data.month}</span>
                <div className="flex items-center gap-3">
                  <div className="w-32 bg-slate-700 rounded-full h-2">
                    <div
                      className="bg-blue-500 h-2 rounded-full"
                      style={{ width: `${(data.students / 1500) * 100}%` }}
                    ></div>
                  </div>
                  <span className="text-blue-400 font-medium">{data.students.toLocaleString()}</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Top Courses */}
      <div className="card">
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-xl font-bold text-white">
            {t('instructor.topCourses', { defaultValue: 'Top Performing Courses' })}
          </h2>
          <button className="btn-ghost flex items-center gap-2">
            <Filter className="w-4 h-4" />
            {t('instructor.filter', { defaultValue: 'Filter' })}
          </button>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="border-b border-slate-700/50">
                <th className="text-left py-3 px-4 text-sm font-medium text-slate-400">
                  {t('instructor.course', { defaultValue: 'Course' })}
                </th>
                <th className="text-left py-3 px-4 text-sm font-medium text-slate-400">
                  {t('instructor.students', { defaultValue: 'Students' })}
                </th>
                <th className="text-left py-3 px-4 text-sm font-medium text-slate-400">
                  {t('instructor.revenue', { defaultValue: 'Revenue' })}
                </th>
                <th className="text-left py-3 px-4 text-sm font-medium text-slate-400">
                  {t('instructor.completion', { defaultValue: 'Completion' })}
                </th>
                <th className="text-left py-3 px-4 text-sm font-medium text-slate-400">
                  {t('instructor.rating', { defaultValue: 'Rating' })}
                </th>
              </tr>
            </thead>
            <tbody>
              {topCourses.map((course, index) => (
                <tr key={index} className="border-b border-slate-700/50 hover:bg-slate-800/50">
                  <td className="py-3 px-4">
                    <p className="text-white font-medium">{course.title}</p>
                  </td>
                  <td className="py-3 px-4">
                    <div className="flex items-center gap-2">
                      <Users className="w-4 h-4 text-slate-400" />
                      <span className="text-white">{course.students}</span>
                    </div>
                  </td>
                  <td className="py-3 px-4">
                    <span className="text-green-400 font-medium">{course.revenue}</span>
                  </td>
                  <td className="py-3 px-4">
                    <div className="flex items-center gap-2">
                      <div className="w-full max-w-[100px] bg-slate-700 rounded-full h-2">
                        <div
                          className="bg-primary-500 h-2 rounded-full"
                          style={{ width: `${course.completion}%` }}
                        ></div>
                      </div>
                      <span className="text-sm text-slate-400">{course.completion}%</span>
                    </div>
                  </td>
                  <td className="py-3 px-4">
                    <div className="flex items-center gap-1">
                      <span className="text-yellow-400">★</span>
                      <span className="text-white">{course.rating}</span>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
