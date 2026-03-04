import React, { useEffect, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { useTranslation } from 'react-i18next';
import { Link, useSearchParams } from 'react-router-dom';
import { fetchCourses, setFilters } from '../../store/slices/courseSlice';
import { Search, Star, Users, Clock, BookOpen, ChevronRight, Loader2 } from 'lucide-react';

const CATEGORIES = ['All', 'Programming', 'Data Science', 'Design', 'Business', 'Marketing', 'DevOps', 'AI/ML'];
const LEVELS = ['All', 'beginner', 'intermediate', 'advanced'];

function CourseCard({ course }) {
  const { t } = useTranslation();
  const gradients = [
    'from-blue-600 to-purple-600', 'from-green-600 to-teal-600',
    'from-orange-600 to-red-600', 'from-pink-600 to-rose-600',
  ];
  const seed = course.id ? parseInt(course.id.replace(/\D/g, '').slice(0, 4) || '0') : 0;
  const gradient = gradients[seed % gradients.length];
  const studentCount = course.total_enrollments ?? course.students ?? 0;
  const price = parseFloat(course.price ?? 0);

  return (
    <div className="card hover:border-slate-600 transition-all duration-200 hover:-translate-y-1 group flex flex-col">
      <div className={`h-36 rounded-xl bg-gradient-to-br ${gradient} mb-4 flex items-center justify-center relative overflow-hidden`}>
        <BookOpen className="w-12 h-12 text-white/30" />
        <div className="absolute top-3 right-3 flex gap-2">
          {price === 0 && <span className="badge-green text-xs">{t('courses.free')}</span>}
          {course.isEnrolled && <span className="badge-blue text-xs">{t('courses.enrolled')}</span>}
        </div>
      </div>

      <div className="flex-1 flex flex-col">
        <div className="flex items-center gap-2 mb-2">
          {course.category_name && <span className="badge-purple text-xs">{course.category_name}</span>}
          {course.level && <span className="badge text-xs bg-slate-700 text-slate-300 capitalize">{course.level}</span>}
        </div>

        <h3 className="font-semibold text-white mb-1 line-clamp-2 group-hover:text-primary-400 transition-colors">
          {course.title}
        </h3>
        <p className="text-sm text-slate-400 mb-3">{course.instructor_name || course.instructor}</p>

        <div className="flex items-center gap-3 text-xs text-slate-400 mb-4">
          {course.rating && (
            <div className="flex items-center gap-1">
              <Star className="w-3.5 h-3.5 text-yellow-400 fill-yellow-400" />
              <span className="text-white font-medium">{parseFloat(course.rating).toFixed(1)}</span>
            </div>
          )}
          <div className="flex items-center gap-1">
            <Users className="w-3.5 h-3.5" />
            <span>{studentCount > 999 ? `${(studentCount / 1000).toFixed(1)}k` : studentCount}</span>
          </div>
          {course.total_duration_hours && (
            <div className="flex items-center gap-1">
              <Clock className="w-3.5 h-3.5" />
              <span>{Math.round(course.total_duration_hours)}h</span>
            </div>
          )}
        </div>

        <div className="mt-auto flex items-center justify-between">
          <div>
            {price === 0 ? (
              <span className="text-green-400 font-bold">{t('courses.free')}</span>
            ) : (
              <span className="text-white font-bold">${price.toFixed(2)}</span>
            )}
          </div>
          <Link
            to={`/courses/${course.id}`}
            className="flex items-center gap-1 text-sm text-primary-400 hover:text-primary-300 font-medium transition-colors"
          >
            {course.isEnrolled ? t('courses.continue') : t('courses.enroll')}
            <ChevronRight className="w-4 h-4" />
          </Link>
        </div>
      </div>
    </div>
  );
}

export default function CoursesPage() {
  const { t } = useTranslation();
  const dispatch = useDispatch();
  const { list: courses, isLoading, total } = useSelector((state) => state.courses);
  const [searchParams] = useSearchParams();
  const [localSearch, setLocalSearch] = useState(searchParams.get('search') || '');
  const [selectedCategory, setSelectedCategory] = useState('All');
  const [selectedLevel, setSelectedLevel] = useState('All');
  const [debouncedSearch, setDebouncedSearch] = useState(localSearch);

  useEffect(() => {
    const t = setTimeout(() => setDebouncedSearch(localSearch), 400);
    return () => clearTimeout(t);
  }, [localSearch]);

  useEffect(() => {
    const params = {};
    if (debouncedSearch) params.search = debouncedSearch;
    if (selectedCategory !== 'All') params.category = selectedCategory;
    if (selectedLevel !== 'All') params.level = selectedLevel;
    dispatch(fetchCourses(params));
    dispatch(setFilters({ search: debouncedSearch, category: selectedCategory !== 'All' ? selectedCategory : '', level: selectedLevel !== 'All' ? selectedLevel : '' }));
  }, [dispatch, debouncedSearch, selectedCategory, selectedLevel]);

  return (
    <div className="space-y-6 animate-slide-up">
      <div>
        <h1 className="text-2xl font-bold text-white">{t('courses.title')}</h1>
        <p className="text-slate-400 mt-1">{t('courses.subtitle')}</p>
      </div>

      <div className="flex flex-col sm:flex-row gap-4">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
          <input
            type="text"
            value={localSearch}
            onChange={(e) => setLocalSearch(e.target.value)}
            placeholder={t('courses.search')}
            className="input-field pl-10"
          />
        </div>
        <select
          value={selectedLevel}
          onChange={(e) => setSelectedLevel(e.target.value)}
          className="input-field w-full sm:w-44"
        >
          <option value="All">All Levels</option>
          {LEVELS.slice(1).map((l) => (
            <option key={l} value={l} className="capitalize">{l.charAt(0).toUpperCase() + l.slice(1)}</option>
          ))}
        </select>
      </div>

      <div className="flex gap-2 flex-wrap">
        {CATEGORIES.map((cat) => (
          <button
            key={cat}
            onClick={() => setSelectedCategory(cat)}
            className={`px-4 py-1.5 rounded-full text-sm font-medium transition-all duration-200 ${
              selectedCategory === cat
                ? 'bg-primary-600 text-white'
                : 'bg-slate-800 text-slate-400 hover:text-white hover:bg-slate-700'
            }`}
          >
            {cat}
          </button>
        ))}
      </div>

      <div className="flex items-center justify-between">
        <p className="text-slate-400 text-sm">
          <span className="text-white font-semibold">{total || courses.length}</span> {t('courses.found', { defaultValue: 'courses found' })}
        </p>
      </div>

      {isLoading ? (
        <div className="flex items-center justify-center py-20">
          <Loader2 className="w-8 h-8 text-primary-400 animate-spin" />
        </div>
      ) : courses.length === 0 ? (
        <div className="text-center py-16">
          <BookOpen className="w-12 h-12 text-slate-600 mx-auto mb-4" />
          <p className="text-slate-400">{t('courses.noCoursesFound')}</p>
          <p className="text-slate-500 text-sm mt-1">{t('courses.tryDifferentSearch')}</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-5">
          {courses.map((course) => (
            <CourseCard key={course.id} course={course} />
          ))}
        </div>
      )}
    </div>
  );
}
