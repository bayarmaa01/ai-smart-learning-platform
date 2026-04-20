import React, { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Link } from 'react-router-dom';
import api from '../../services/api';
import {
  BookOpen,
  Users,
  Clock,
  DollarSign,
  TrendingUp,
  Plus,
  Search,
  Filter,
  MoreVertical
} from 'lucide-react';

export default function InstructorCourses() {
  const { t } = useTranslation();
  const [courses, setCourses] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');

  useEffect(() => {
    const fetchCourses = async () => {
      try {
        console.log('Fetching instructor courses...');
        const response = await api.get('/courses/instructor');
        console.log('Instructor courses response:', response.data);
        setCourses(response.data.courses || []);
      } catch (error) {
        console.error('Failed to fetch instructor courses:', error);
        setCourses([]);
      } finally {
        setLoading(false);
      }
    };

    fetchCourses();
  }, []);

  const getStatusColor = (status) => {
    switch (status) {
      case 'published':
        return 'bg-green-500/20 text-green-300 border border-green-500/30';
      case 'draft':
        return 'bg-yellow-500/20 text-yellow-300 border border-yellow-500/30';
      case 'archived':
        return 'bg-red-500/20 text-red-300 border border-red-500/30';
      default:
        return 'bg-slate-500/20 text-slate-300 border border-slate-500/30';
    }
  };

  const filteredCourses = courses.filter(course => 
    course.title?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    course.description?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  return (
    <div className="animate-fade-in">
      <div className="flex items-center justify-between mb-8">
        <div>
          <h1 className="text-3xl font-bold text-white mb-2">
            {t('instructor.myCourses', { defaultValue: 'My Courses' })}
          </h1>
          <p className="text-slate-400">
            {t('instructor.manageCourses', { defaultValue: 'Manage and create your courses' })}
          </p>
        </div>
        <Link to="/instructor/create-course" className="btn-primary flex items-center gap-2">
          <Plus className="w-4 h-4" />
          {t('instructor.createCourse', { defaultValue: 'Create Course' })}
        </Link>
      </div>

      {/* Search and Filter */}
      <div className="card mb-6">
        <div className="flex flex-col sm:flex-row gap-4">
          <div className="flex-1 relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-slate-400" />
            <input
              type="text"
              placeholder={t('instructor.searchCourses', { defaultValue: 'Search courses...' })}
              className="w-full pl-10 pr-4 py-2 bg-slate-800/50 border border-slate-600/50 rounded-lg text-white placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-transparent"
            />
          </div>
          <button className="btn-ghost flex items-center gap-2">
            <Filter className="w-4 h-4" />
            {t('instructor.filter', { defaultValue: 'Filter' })}
          </button>
        </div>
      </div>

      {/* Courses Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {filteredCourses.length === 0 ? (
          <div className="col-span-full text-center py-12">
            <BookOpen className="w-12 h-12 text-slate-400 mx-auto mb-4" />
            <h3 className="text-lg font-medium text-white mb-2">
              {courses.length === 0 
                ? t('instructor.noCourses', { defaultValue: 'No courses yet' })
                : t('instructor.noMatchingCourses', { defaultValue: 'No matching courses' })
              }
            </h3>
            <p className="text-slate-400 mb-4">
              {courses.length === 0 
                ? t('instructor.createFirstCourse', { defaultValue: 'Create your first course to get started' })
                : t('instructor.tryDifferentSearch', { defaultValue: 'Try adjusting your search terms' })
              }
            </p>
            {courses.length === 0 && (
              <Link to="/instructor/create-course" className="btn-primary">
                <Plus className="w-4 h-4 mr-2" />
                {t('instructor.createCourse', { defaultValue: 'Create Course' })}
              </Link>
            )}
          </div>
        ) : (
          filteredCourses.map((course) => (
          <div key={course.id} className="card group">
            <div className="aspect-video bg-slate-800 rounded-lg mb-4 overflow-hidden">
              <img
                src={course.thumbnail}
                alt={course.title}
                className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
              />
            </div>
            
            <div className="flex items-start justify-between mb-3">
              <div className="flex-1">
                <h3 className="text-lg font-semibold text-white mb-1 line-clamp-1">
                  {course.title}
                </h3>
                <p className="text-sm text-slate-400 line-clamp-2">{course.description}</p>
              </div>
              <button className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-700/50 transition-colors">
                <MoreVertical className="w-4 h-4" />
              </button>
            </div>

            <div className="flex items-center gap-4 text-sm text-slate-400 mb-3">
              <div className="flex items-center gap-1">
                <Users className="w-4 h-4" />
                <span>{course.students}</span>
              </div>
              <div className="flex items-center gap-1">
                <Clock className="w-4 h-4" />
                <span>{course.duration}</span>
              </div>
              <div className="flex items-center gap-1">
                <DollarSign className="w-4 h-4" />
                <span>{course.price}</span>
              </div>
            </div>

            <div className="flex items-center justify-between mb-3">
              <div className="flex items-center gap-1">
                <span className="text-yellow-400">★</span>
                <span className="text-white font-medium">{course.rating}</span>
              </div>
              <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getStatusColor(course.status)}`}>
                {course.status}
              </span>
            </div>

            {course.status === 'published' && (
              <div className="space-y-2">
                <div className="flex items-center justify-between text-sm">
                  <span className="text-slate-400">{t('instructor.progress', { defaultValue: 'Progress' })}</span>
                  <span className="text-white">{course.progress}%</span>
                </div>
                <div className="w-full bg-slate-700 rounded-full h-2">
                  <div
                    className="bg-primary-500 h-2 rounded-full"
                    style={{ width: `${course.progress}%` }}
                  ></div>
                </div>
              </div>
            )}

            <div className="flex items-center justify-between pt-3 border-t border-slate-700/50">
              <span className="text-green-400 font-medium">
                ${course.enrollment_count ? (course.enrollment_count * (course.price || 0)).toLocaleString() : '0'}
              </span>
              <Link
                to={`/instructor/courses/${course.id}`}
                className="text-primary-400 hover:text-primary-300 text-sm font-medium"
              >
                {t('instructor.viewDetails', { defaultValue: 'View Details' })}
              </Link>
            </div>
          </div>
        ))
        )}
      </div>
    </div>
  );
}
