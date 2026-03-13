import React, { useState } from 'react';
import { useTranslation } from 'react-i18next';
import {
  Users,
  Search,
  Filter,
  Download,
  Mail,
  MessageSquare,
  TrendingUp,
  Award,
  Clock,
  MoreVertical
} from 'lucide-react';

export default function InstructorStudents() {
  const { t } = useTranslation();
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedCourse, setSelectedCourse] = useState('all');

  const students = [
    {
      id: 1,
      name: 'John Doe',
      email: 'john@example.com',
      avatar: '/api/placeholder/40/40',
      enrolledCourses: 3,
      completedCourses: 2,
      totalProgress: 75,
      lastActive: '2 hours ago',
      averageGrade: 85,
      joinDate: '2024-01-15',
      status: 'active',
    },
    {
      id: 2,
      name: 'Jane Smith',
      email: 'jane@example.com',
      avatar: '/api/placeholder/40/40',
      enrolledCourses: 5,
      completedCourses: 4,
      totalProgress: 82,
      lastActive: '1 day ago',
      averageGrade: 92,
      joinDate: '2024-01-10',
      status: 'active',
    },
    {
      id: 3,
      name: 'Mike Johnson',
      email: 'mike@example.com',
      avatar: '/api/placeholder/40/40',
      enrolledCourses: 2,
      completedCourses: 1,
      totalProgress: 45,
      lastActive: '3 days ago',
      averageGrade: 78,
      joinDate: '2024-01-20',
      status: 'inactive',
    },
  ];

  const courses = [
    { id: 'all', name: t('instructor.allCourses', { defaultValue: 'All Courses' }) },
    { id: '1', name: 'Advanced React Development' },
    { id: '2', name: 'Node.js Masterclass' },
    { id: '3', name: 'Python for Beginners' },
  ];

  const filteredStudents = students.filter(student => {
    const matchesSearch = student.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         student.email.toLowerCase().includes(searchTerm.toLowerCase());
    const matchesCourse = selectedCourse === 'all' || student.enrolledCourses > 0;
    return matchesSearch && matchesCourse;
  });

  const getStatusColor = (status) => {
    switch (status) {
      case 'active':
        return 'bg-green-500/20 text-green-300 border border-green-500/30';
      case 'inactive':
        return 'bg-yellow-500/20 text-yellow-300 border border-yellow-500/30';
      default:
        return 'bg-slate-500/20 text-slate-300 border border-slate-500/30';
    }
  };

  return (
    <div className="animate-fade-in">
      <div className="flex items-center justify-between mb-8">
        <div>
          <h1 className="text-3xl font-bold text-white mb-2">
            {t('instructor.students', { defaultValue: 'Students' })}
          </h1>
          <p className="text-slate-400">
            {t('instructor.manageStudents', { defaultValue: 'Manage and monitor your students' })}
          </p>
        </div>
        <button className="btn-primary flex items-center gap-2">
          <Download className="w-4 h-4" />
          {t('instructor.exportData', { defaultValue: 'Export Data' })}
        </button>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
        <div className="card">
          <div className="flex items-center justify-between mb-4">
            <div className="w-12 h-12 bg-blue-500 rounded-lg flex items-center justify-center">
              <Users className="w-6 h-6 text-white" />
            </div>
            <span className="text-sm text-green-400 font-medium">+12% this month</span>
          </div>
          <h3 className="text-2xl font-bold text-white mb-1">1,248</h3>
          <p className="text-sm text-slate-400">{t('instructor.totalStudents', { defaultValue: 'Total Students' })}</p>
        </div>

        <div className="card">
          <div className="flex items-center justify-between mb-4">
            <div className="w-12 h-12 bg-green-500 rounded-lg flex items-center justify-center">
              <TrendingUp className="w-6 h-6 text-white" />
            </div>
            <span className="text-sm text-green-400 font-medium">+8% this month</span>
          </div>
          <h3 className="text-2xl font-bold text-white mb-1">82%</h3>
          <p className="text-sm text-slate-400">{t('instructor.avgProgress', { defaultValue: 'Avg. Progress' })}</p>
        </div>

        <div className="card">
          <div className="flex items-center justify-between mb-4">
            <div className="w-12 h-12 bg-yellow-500 rounded-lg flex items-center justify-center">
              <Award className="w-6 h-6 text-white" />
            </div>
            <span className="text-sm text-green-400 font-medium">+5% this month</span>
          </div>
          <h3 className="text-2xl font-bold text-white mb-1">87%</h3>
          <p className="text-sm text-slate-400">{t('instructor.completionRate', { defaultValue: 'Completion Rate' })}</p>
        </div>

        <div className="card">
          <div className="flex items-center justify-between mb-4">
            <div className="w-12 h-12 bg-purple-500 rounded-lg flex items-center justify-center">
              <Clock className="w-6 h-6 text-white" />
            </div>
            <span className="text-sm text-green-400 font-medium">-2% this month</span>
          </div>
          <h3 className="text-2xl font-bold text-white mb-1">4.2h</h3>
          <p className="text-sm text-slate-400">{t('instructor.avgSessionTime', { defaultValue: 'Avg. Session Time' })}</p>
        </div>
      </div>

      {/* Search and Filter */}
      <div className="card mb-6">
        <div className="flex flex-col sm:flex-row gap-4">
          <div className="flex-1 relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-slate-400" />
            <input
              type="text"
              placeholder={t('instructor.searchStudents', { defaultValue: 'Search students...' })}
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="w-full pl-10 pr-4 py-2 bg-slate-800/50 border border-slate-600/50 rounded-lg text-white placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-transparent"
            />
          </div>
          <select
            value={selectedCourse}
            onChange={(e) => setSelectedCourse(e.target.value)}
            className="px-4 py-2 bg-slate-800/50 border border-slate-600/50 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-transparent"
          >
            {courses.map(course => (
              <option key={course.id} value={course.id}>{course.name}</option>
            ))}
          </select>
          <button className="btn-ghost flex items-center gap-2">
            <Filter className="w-4 h-4" />
            {t('instructor.moreFilters', { defaultValue: 'More Filters' })}
          </button>
        </div>
      </div>

      {/* Students Table */}
      <div className="card">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="border-b border-slate-700/50">
                <th className="text-left py-3 px-4 text-sm font-medium text-slate-400">
                  {t('instructor.student', { defaultValue: 'Student' })}
                </th>
                <th className="text-left py-3 px-4 text-sm font-medium text-slate-400">
                  {t('instructor.courses', { defaultValue: 'Courses' })}
                </th>
                <th className="text-left py-3 px-4 text-sm font-medium text-slate-400">
                  {t('instructor.progress', { defaultValue: 'Progress' })}
                </th>
                <th className="text-left py-3 px-4 text-sm font-medium text-slate-400">
                  {t('instructor.grade', { defaultValue: 'Grade' })}
                </th>
                <th className="text-left py-3 px-4 text-sm font-medium text-slate-400">
                  {t('instructor.lastActive', { defaultValue: 'Last Active' })}
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
              {filteredStudents.map((student) => (
                <tr key={student.id} className="border-b border-slate-700/50 hover:bg-slate-800/50">
                  <td className="py-3 px-4">
                    <div className="flex items-center gap-3">
                      <img
                        src={student.avatar}
                        alt={student.name}
                        className="w-10 h-10 rounded-full"
                      />
                      <div>
                        <p className="text-white font-medium">{student.name}</p>
                        <p className="text-sm text-slate-400">{student.email}</p>
                      </div>
                    </div>
                  </td>
                  <td className="py-3 px-4">
                    <div className="text-center">
                      <p className="text-white font-medium">{student.enrolledCourses}</p>
                      <p className="text-xs text-slate-400">
                        {student.completedCourses} {t('instructor.completed', { defaultValue: 'completed' })}
                      </p>
                    </div>
                  </td>
                  <td className="py-3 px-4">
                    <div className="flex items-center gap-2">
                      <div className="w-full max-w-[100px] bg-slate-700 rounded-full h-2">
                        <div
                          className="bg-primary-500 h-2 rounded-full"
                          style={{ width: `${student.totalProgress}%` }}
                        ></div>
                      </div>
                      <span className="text-sm text-slate-400">{student.totalProgress}%</span>
                    </div>
                  </td>
                  <td className="py-3 px-4">
                    <span className="text-green-400 font-medium">{student.averageGrade}%</span>
                  </td>
                  <td className="py-3 px-4">
                    <span className="text-sm text-slate-400">{student.lastActive}</span>
                  </td>
                  <td className="py-3 px-4">
                    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getStatusColor(student.status)}`}>
                      {student.status}
                    </span>
                  </td>
                  <td className="py-3 px-4">
                    <div className="flex items-center gap-2">
                      <button className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-700/50 transition-colors">
                        <Mail className="w-4 h-4" />
                      </button>
                      <button className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-700/50 transition-colors">
                        <MessageSquare className="w-4 h-4" />
                      </button>
                      <button className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-700/50 transition-colors">
                        <MoreVertical className="w-4 h-4" />
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
