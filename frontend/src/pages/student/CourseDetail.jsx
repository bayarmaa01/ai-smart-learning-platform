import React, { useState } from 'react';
import { useParams, Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { Star, Users, Clock, BookOpen, Award, Play, ChevronDown, ChevronUp, Check } from 'lucide-react';

const mockCourse = {
  id: '1',
  title: 'Machine Learning A-Z: AI, Python & R + ChatGPT Bonus',
  instructor: 'Dr. Sarah Chen',
  rating: 4.8,
  students: 45230,
  duration: '42h',
  lessons: 320,
  level: 'Intermediate',
  category: 'AI/ML',
  price: 0,
  isEnrolled: true,
  description: 'Master Machine Learning with Python & R. From data preprocessing to deep learning, this comprehensive course covers everything you need.',
  whatYouLearn: [
    'Build Machine Learning algorithms in Python and R',
    'Make accurate predictions and powerful analysis',
    'Use Machine Learning for personal purpose',
    'Handle specific topics like Reinforcement Learning, NLP and Deep Learning',
    'Handle advanced techniques like Dimensionality Reduction',
    'Know which Machine Learning model to choose for each type of problem',
  ],
  requirements: [
    'Just some high school mathematics level',
    'Basic Python or R programming knowledge',
  ],
  curriculum: [
    {
      title: 'Data Preprocessing', lessons: [
        { id: '1', title: 'Welcome to the course', duration: '5:30', free: true },
        { id: '2', title: 'Getting the Dataset', duration: '8:15', free: true },
        { id: '3', title: 'Importing the Libraries', duration: '6:45', free: false },
        { id: '4', title: 'Handling Missing Data', duration: '12:20', free: false },
      ]
    },
    {
      title: 'Regression', lessons: [
        { id: '5', title: 'Simple Linear Regression', duration: '15:00', free: false },
        { id: '6', title: 'Multiple Linear Regression', duration: '18:30', free: false },
        { id: '7', title: 'Polynomial Regression', duration: '14:00', free: false },
      ]
    },
    {
      title: 'Classification', lessons: [
        { id: '8', title: 'Logistic Regression', duration: '16:45', free: false },
        { id: '9', title: 'K-Nearest Neighbors', duration: '12:30', free: false },
        { id: '10', title: 'Support Vector Machine', duration: '20:00', free: false },
      ]
    },
  ],
};

export default function CourseDetailPage() {
  const { t } = useTranslation();
  const { id } = useParams();
  const [expandedSection, setExpandedSection] = useState(0);
  const course = mockCourse;

  return (
    <div className="animate-slide-up">
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2 space-y-6">
          <div>
            <div className="flex items-center gap-2 mb-3">
              <span className="badge-purple">{course.category}</span>
              <span className="badge bg-slate-700 text-slate-300">{course.level}</span>
            </div>
            <h1 className="text-2xl font-bold text-white mb-3">{course.title}</h1>
            <p className="text-slate-400 mb-4">{course.description}</p>

            <div className="flex flex-wrap items-center gap-4 text-sm text-slate-400">
              <div className="flex items-center gap-1">
                <Star className="w-4 h-4 text-yellow-400 fill-yellow-400" />
                <span className="text-white font-medium">{course.rating}</span>
                <span>({(course.students / 1000).toFixed(1)}k reviews)</span>
              </div>
              <div className="flex items-center gap-1">
                <Users className="w-4 h-4" />
                <span>{course.students.toLocaleString()} {t('courses.students')}</span>
              </div>
              <div className="flex items-center gap-1">
                <Clock className="w-4 h-4" />
                <span>{course.duration} {t('courses.hours')}</span>
              </div>
              <div className="flex items-center gap-1">
                <BookOpen className="w-4 h-4" />
                <span>{course.lessons} {t('courses.lessons')}</span>
              </div>
            </div>
          </div>

          <div className="card">
            <h2 className="text-lg font-semibold text-white mb-4">{t('courses.whatYouLearn')}</h2>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              {course.whatYouLearn.map((item, i) => (
                <div key={i} className="flex items-start gap-2">
                  <Check className="w-4 h-4 text-green-400 mt-0.5 flex-shrink-0" />
                  <span className="text-sm text-slate-300">{item}</span>
                </div>
              ))}
            </div>
          </div>

          <div className="card">
            <h2 className="text-lg font-semibold text-white mb-4">{t('courses.curriculum')}</h2>
            <div className="space-y-2">
              {course.curriculum.map((section, i) => (
                <div key={i} className="border border-slate-700 rounded-xl overflow-hidden">
                  <button
                    onClick={() => setExpandedSection(expandedSection === i ? -1 : i)}
                    className="w-full flex items-center justify-between p-4 hover:bg-slate-800/50 transition-colors"
                  >
                    <div className="flex items-center gap-3">
                      <span className="font-medium text-white">{section.title}</span>
                      <span className="text-xs text-slate-400">{section.lessons.length} lessons</span>
                    </div>
                    {expandedSection === i ? <ChevronUp className="w-4 h-4 text-slate-400" /> : <ChevronDown className="w-4 h-4 text-slate-400" />}
                  </button>
                  {expandedSection === i && (
                    <div className="border-t border-slate-700">
                      {section.lessons.map((lesson) => (
                        <div key={lesson.id} className="flex items-center justify-between px-4 py-3 hover:bg-slate-800/30 transition-colors">
                          <div className="flex items-center gap-3">
                            <Play className="w-4 h-4 text-slate-400" />
                            <span className="text-sm text-slate-300">{lesson.title}</span>
                            {lesson.free && <span className="badge-green text-xs">Free</span>}
                          </div>
                          <span className="text-xs text-slate-400">{lesson.duration}</span>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              ))}
            </div>
          </div>
        </div>

        <div className="lg:col-span-1">
          <div className="card sticky top-20">
            <div className="h-40 bg-gradient-to-br from-primary-600 to-accent-600 rounded-xl flex items-center justify-center mb-4">
              <BookOpen className="w-16 h-16 text-white/30" />
            </div>

            <div className="mb-4">
              {course.price === 0 ? (
                <p className="text-2xl font-bold text-green-400">{t('courses.free')}</p>
              ) : (
                <p className="text-2xl font-bold text-white">${course.price}</p>
              )}
            </div>

            {course.isEnrolled ? (
              <Link to={`/courses/${course.id}/learn`} className="btn-primary w-full flex items-center justify-center gap-2 mb-3">
                <Play className="w-4 h-4" />
                {t('courses.continue')}
              </Link>
            ) : (
              <button className="btn-primary w-full mb-3">{t('courses.enroll')}</button>
            )}

            <div className="space-y-2 text-sm">
              {[
                { icon: Clock, label: `${course.duration} of content` },
                { icon: BookOpen, label: `${course.lessons} lessons` },
                { icon: Award, label: 'Certificate of completion' },
              ].map(({ icon: Icon, label }) => (
                <div key={label} className="flex items-center gap-2 text-slate-400">
                  <Icon className="w-4 h-4" />
                  <span>{label}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
