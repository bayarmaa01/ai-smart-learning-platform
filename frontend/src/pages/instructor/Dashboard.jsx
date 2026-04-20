import React, { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useSelector } from 'react-redux';
import { Link } from 'react-router-dom';
import api from '../../services/api';
import {
  BookOpen,
  Users,
  DollarSign,
  TrendingUp,
  Plus,
  Eye,
  BarChart3,
  Clock
} from 'lucide-react';

export default function InstructorDashboard() {
  const { t } = useTranslation();
  const { user } = useSelector((state) => state.auth);
  const [stats, setStats] = useState(null);
  const [recentCourses, setRecentCourses] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchDashboardData = async () => {
      try {
        console.log('Fetching instructor dashboard data...');
        
        // Fetch instructor stats
        try {
          const statsResponse = await api.get('/courses/instructor/stats');
          console.log('Instructor stats:', statsResponse.data);
          setStats(statsResponse.data.stats || {
            totalCourses: 0,
            totalStudents: 0,
            revenue: 0,
            completionRate: 0
          });
        } catch (statsError) {
          console.warn('Stats endpoint not available, using fallback:', statsError.message);
          // Fallback stats
          setStats({
            totalCourses: 0,
            totalStudents: 0,
            revenue: 0,
            completionRate: 0
          });
        }

        // Fetch instructor courses
        try {
          const coursesResponse = await api.get('/courses/instructor');
          console.log('Instructor courses:', coursesResponse.data);
          setRecentCourses(coursesResponse.data.courses?.slice(0, 5) || []);
        } catch (coursesError) {
          console.warn('Courses endpoint error:', coursesError.message);
          setRecentCourses([]);
        }
      } catch (error) {
        console.error('Dashboard data fetch error:', error);
        // Set fallback data
        setStats({
          totalCourses: 0,
          totalStudents: 0,
          revenue: 0,
          completionRate: 0
        });
        setRecentCourses([]);
      } finally {
        setLoading(false);
      }
    };

    if (user) {
      fetchDashboardData();
    }
  }, [user]);

  const statsData = stats ? [
    {
      title: t('instructor.totalCourses', { defaultValue: 'Total Courses' }),
      value: stats.totalCourses?.toString() || '0',
      change: stats.courseGrowth || '+0 this month',
      icon: BookOpen,
      color: 'bg-blue-500',
    },
    {
      title: t('instructor.totalStudents', { defaultValue: 'Total Students' }),
      value: stats.totalStudents?.toLocaleString() || '0',
      change: stats.studentGrowth || '+0 this month',
      icon: Users,
      color: 'bg-green-500',
    },
    {
      title: t('instructor.revenue', { defaultValue: 'Revenue' }),
      value: `$${stats.revenue?.toLocaleString() || '0'}`,
      change: stats.revenueGrowth || '+0% from last month',
      icon: DollarSign,
      color: 'bg-yellow-500',
    },
    {
      title: t('instructor.completionRate', { defaultValue: 'Completion Rate' }),
      value: `${stats.completionRate || 0}%`,
      change: stats.completionGrowth || '+0% from last month',
      icon: TrendingUp,
      color: 'bg-purple-500',
    },
  ] : [];

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  return (
    <div className="animate-fade-in">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-white mb-2">
          {t('instructor.dashboard', { defaultValue: 'Instructor Dashboard' })}
        </h1>
        <p className="text-slate-400">
          {t('instructor.welcome', { defaultValue: 'Welcome back! Here\'s what\'s happening with your courses.' })}
        </p>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        {statsData.map((stat, index) => (
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

      {/* Recent Courses */}
      <div className="card">
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-xl font-bold text-white">
            {t('instructor.recentCourses', { defaultValue: 'Recent Courses' })}
          </h2>
          <Link to="/instructor/create-course" className="btn-primary flex items-center gap-2">
            <Plus className="w-4 h-4" />
            {t('instructor.createCourse', { defaultValue: 'Create Course' })}
          </Link>
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
                  {t('instructor.progress', { defaultValue: 'Progress' })}
                </th>
                <th className="text-left py-3 px-4 text-sm font-medium text-slate-400">
                  {t('instructor.revenue', { defaultValue: 'Revenue' })}
                </th>
                <th className="text-left py-3 px-4 text-sm font-medium text-slate-400">
                  {t('instructor.status', { defaultValue: 'Status' })}
                </th>
                <th className="text-left py-3 px-4 text-sm font-medium text-slate-400">
                  {t('instructor.actions', { defaultValue: 'Actions' })}
                </th>
              </tr>
            </thead>
            <tbody>
              {recentCourses.map((course) => (
                <tr key={course.id} className="border-b border-slate-700/50 hover:bg-slate-800/50">
                  <td className="py-3 px-4">
                    <div>
                      <p className="text-white font-medium">{course.title}</p>
                    </div>
                  </td>
                  <td className="py-3 px-4">
                    <div className="flex items-center gap-2">
                      <Users className="w-4 h-4 text-slate-400" />
                      <span className="text-white">{course.students}</span>
                    </div>
                  </td>
                  <td className="py-3 px-4">
                    <div className="flex items-center gap-2">
                      <div className="w-full max-w-[100px] bg-slate-700 rounded-full h-2">
                        <div
                          className="bg-primary-500 h-2 rounded-full"
                          style={{ width: `${course.progress}%` }}
                        ></div>
                      </div>
                      <span className="text-sm text-slate-400">{course.progress}%</span>
                    </div>
                  </td>
                  <td className="py-3 px-4">
                    <span className="text-green-400 font-medium">{course.revenue}</span>
                  </td>
                  <td className="py-3 px-4">
                    <span
                      className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                        course.status === 'active'
                          ? 'bg-green-500/20 text-green-300 border border-green-500/30'
                          : 'bg-yellow-500/20 text-yellow-300 border border-yellow-500/30'
                      }`}
                    >
                      {course.status}
                    </span>
                  </td>
                  <td className="py-3 px-4">
                    <div className="flex items-center gap-2">
                      <Link 
                        to={`/instructor/courses/${course.id}`}
                        className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-700/50 transition-colors"
                      >
                        <Eye className="w-4 h-4" />
                      </Link>
                      <button className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-700/50 transition-colors">
                        <BarChart3 className="w-4 h-4" />
                      </button>
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
