import React, { useEffect, useState } from 'react';
import { useParams, Link, useNavigate } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import { useTranslation } from 'react-i18next';
import { fetchCourseById, enrollCourse } from '../../store/slices/courseSlice';
import { Star, Users, Clock, BookOpen, Award, Play, ChevronDown, ChevronUp, Check, Loader2, AlertCircle } from 'lucide-react';
import toast from 'react-hot-toast';

export default function CourseDetailPage() {
  const { t } = useTranslation();
  const { id } = useParams();
  const dispatch = useDispatch();
  const navigate = useNavigate();
  const { currentCourse: course, isLoading, error } = useSelector((state) => state.courses);
  const [expandedSection, setExpandedSection] = useState(0);
  const [enrolling, setEnrolling] = useState(false);

  useEffect(() => {
    if (id) dispatch(fetchCourseById(id));
  }, [dispatch, id]);

  const handleEnroll = async () => {
    setEnrolling(true);
    const result = await dispatch(enrollCourse(id));
    setEnrolling(false);
    if (enrollCourse.fulfilled.match(result)) {
      toast.success(t('courses.enrollSuccess', { defaultValue: 'Enrolled successfully!' }));
      navigate(`/courses/${id}/learn`);
    } else {
      toast.error(result.payload || 'Enrollment failed');
    }
  };

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-32">
        <Loader2 className="w-10 h-10 text-primary-400 animate-spin" />
      </div>
    );
  }

  if (error || !course) {
    return (
      <div className="flex flex-col items-center justify-center py-32 text-center">
        <AlertCircle className="w-12 h-12 text-red-400 mb-4" />
        <h2 className="text-xl font-semibold text-white mb-2">Course not found</h2>
        <p className="text-slate-400 mb-6">{error || 'This course does not exist or has been removed.'}</p>
        <Link to="/courses" className="btn-primary">Browse Courses</Link>
      </div>
    );
  }

  const price = parseFloat(course.price ?? 0);
  const curriculum = course.curriculum || course.sections || [];

  return (
    <div className="animate-slide-up">
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2 space-y-6">
          <div>
            <div className="flex items-center gap-2 mb-3">
              {course.category_name && <span className="badge-purple">{course.category_name}</span>}
              {course.level && <span className="badge bg-slate-700 text-slate-300 capitalize">{course.level}</span>}
            </div>
            <h1 className="text-2xl font-bold text-white mb-3">{course.title}</h1>
            <p className="text-slate-400 mb-4">{course.description}</p>

            <div className="flex flex-wrap items-center gap-4 text-sm text-slate-400">
              {course.rating && (
                <div className="flex items-center gap-1">
                  <Star className="w-4 h-4 text-yellow-400 fill-yellow-400" />
                  <span className="text-white font-medium">{parseFloat(course.rating).toFixed(1)}</span>
                  <span>({(course.total_enrollments / 1000).toFixed(1)}k reviews)</span>
                </div>
              )}
              {course.total_enrollments > 0 && (
                <div className="flex items-center gap-1">
                  <Users className="w-4 h-4" />
                  <span>{course.total_enrollments?.toLocaleString()} {t('courses.students')}</span>
                </div>
              )}
              {course.total_duration_hours && (
                <div className="flex items-center gap-1">
                  <Clock className="w-4 h-4" />
                  <span>{Math.round(course.total_duration_hours)}h {t('courses.hours')}</span>
                </div>
              )}
              {course.total_lessons && (
                <div className="flex items-center gap-1">
                  <BookOpen className="w-4 h-4" />
                  <span>{course.total_lessons} {t('courses.lessons')}</span>
                </div>
              )}
            </div>
            {course.instructor_name && (
              <p className="text-sm text-slate-400 mt-3">
                {t('courses.instructor', { defaultValue: 'Instructor' })}: <span className="text-white">{course.instructor_name}</span>
              </p>
            )}
          </div>

          {course.what_you_learn?.length > 0 && (
            <div className="card">
              <h2 className="text-lg font-semibold text-white mb-4">{t('courses.whatYouLearn')}</h2>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                {course.what_you_learn.map((item, i) => (
                  <div key={i} className="flex items-start gap-2">
                    <Check className="w-4 h-4 text-green-400 mt-0.5 flex-shrink-0" />
                    <span className="text-sm text-slate-300">{item}</span>
                  </div>
                ))}
              </div>
            </div>
          )}

          {curriculum.length > 0 && (
            <div className="card">
              <h2 className="text-lg font-semibold text-white mb-4">{t('courses.curriculum')}</h2>
              <div className="space-y-2">
                {curriculum.map((section, i) => (
                  <div key={i} className="border border-slate-700 rounded-xl overflow-hidden">
                    <button
                      onClick={() => setExpandedSection(expandedSection === i ? -1 : i)}
                      className="w-full flex items-center justify-between p-4 hover:bg-slate-800/50 transition-colors"
                    >
                      <div className="flex items-center gap-3">
                        <span className="font-medium text-white">{section.title}</span>
                        <span className="text-xs text-slate-400">{section.lessons?.length || 0} lessons</span>
                      </div>
                      {expandedSection === i
                        ? <ChevronUp className="w-4 h-4 text-slate-400" />
                        : <ChevronDown className="w-4 h-4 text-slate-400" />}
                    </button>
                    {expandedSection === i && section.lessons?.length > 0 && (
                      <div className="border-t border-slate-700">
                        {section.lessons.map((lesson) => (
                          <div key={lesson.id} className="flex items-center justify-between px-4 py-3 hover:bg-slate-800/30 transition-colors">
                            <div className="flex items-center gap-3">
                              <Play className="w-4 h-4 text-slate-400" />
                              <span className="text-sm text-slate-300">{lesson.title}</span>
                              {lesson.is_free && <span className="badge-green text-xs">Free</span>}
                            </div>
                            {lesson.duration_seconds && (
                              <span className="text-xs text-slate-400">
                                {Math.floor(lesson.duration_seconds / 60)}:{String(lesson.duration_seconds % 60).padStart(2, '0')}
                              </span>
                            )}
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>

        <div className="lg:col-span-1">
          <div className="card sticky top-20">
            <div className="h-40 bg-gradient-to-br from-primary-600 to-accent-600 rounded-xl flex items-center justify-center mb-4">
              <BookOpen className="w-16 h-16 text-white/30" />
            </div>

            <div className="mb-4">
              {price === 0 ? (
                <p className="text-2xl font-bold text-green-400">{t('courses.free')}</p>
              ) : (
                <p className="text-2xl font-bold text-white">${price.toFixed(2)}</p>
              )}
            </div>

            {course.isEnrolled ? (
              <Link
                to={`/courses/${course.id}/learn`}
                className="btn-primary w-full flex items-center justify-center gap-2 mb-3"
              >
                <Play className="w-4 h-4" />
                {t('courses.continue')}
              </Link>
            ) : (
              <button
                onClick={handleEnroll}
                disabled={enrolling}
                className="btn-primary w-full mb-3 flex items-center justify-center gap-2"
              >
                {enrolling ? <Loader2 className="w-4 h-4 animate-spin" /> : null}
                {t('courses.enroll')}
              </button>
            )}

            <div className="space-y-2 text-sm">
              {course.total_duration_hours && (
                <div className="flex items-center gap-2 text-slate-400">
                  <Clock className="w-4 h-4" />
                  <span>{Math.round(course.total_duration_hours)}h of content</span>
                </div>
              )}
              {course.total_lessons && (
                <div className="flex items-center gap-2 text-slate-400">
                  <BookOpen className="w-4 h-4" />
                  <span>{course.total_lessons} lessons</span>
                </div>
              )}
              <div className="flex items-center gap-2 text-slate-400">
                <Award className="w-4 h-4" />
                <span>Certificate of completion</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
