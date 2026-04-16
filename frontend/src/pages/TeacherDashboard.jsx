import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import api from '../services/api';

const TeacherDashboard = ({ user }) => {
  const [courses, setCourses] = useState([]);
  const [students, setStudents] = useState([]);
  const [loading, setLoading] = useState(true);
  const [stats, setStats] = useState({
    totalCourses: 0,
    totalStudents: 0,
    totalRevenue: 0,
    avgRating: 0
  });

  useEffect(() => {
    const fetchTeacherData = async () => {
      try {
        setLoading(true);
        
        // Fetch teacher's courses
        const coursesResponse = await api.get('/courses/instructor');
        setCourses(coursesResponse.data.courses || []);

        // Fetch teacher's students
        const studentsResponse = await api.get('/users/students');
        setStudents(studentsResponse.data.students || []);

        // Fetch teacher stats
        const statsResponse = await api.get('/users/teacher-stats');
        setStats(statsResponse.data.stats || {
          totalCourses: 0,
          totalStudents: 0,
          totalRevenue: 0,
          avgRating: 0
        });
      } catch (error) {
        console.error('Failed to fetch teacher data:', error);
      } finally {
        setLoading(false);
      }
    };

    fetchTeacherData();
  }, []);

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-gray-900">Teacher Dashboard</h1>
          <p className="mt-2 text-gray-600">Welcome back, {user.firstName}!</p>
        </div>

        {/* Stats Cards */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <div className="bg-white overflow-hidden shadow rounded-lg">
            <div className="p-5">
              <div className="flex items-center">
                <div className="flex-shrink-0 bg-purple-500 rounded-md p-3">
                  <svg className="h-6 w-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6.253v13m0-13L1.216 0l7.194 7.194L12 19.253z" />
                  </svg>
                </div>
                <div className="ml-5 w-0 flex items-center justify-between">
                  <div className="ml-3">
                    <p className="text-sm font-medium text-gray-900">Total Courses</p>
                    <p className="text-lg font-semibold text-gray-900">{stats.totalCourses}</p>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div className="bg-white overflow-hidden shadow rounded-lg">
            <div className="p-5">
              <div className="flex items-center">
                <div className="flex-shrink-0 bg-green-500 rounded-md p-3">
                  <svg className="h-6 w-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
                  </svg>
                </div>
                <div className="ml-5 w-0 flex items-center justify-between">
                  <div className="ml-3">
                    <p className="text-sm font-medium text-gray-900">Total Students</p>
                    <p className="text-lg font-semibold text-gray-900">{stats.totalStudents}</p>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div className="bg-white overflow-hidden shadow rounded-lg">
            <div className="p-5">
              <div className="flex items-center">
                <div className="flex-shrink-0 bg-yellow-500 rounded-md p-3">
                  <svg className="h-6 w-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1" />
                  </svg>
                </div>
                <div className="ml-5 w-0 flex items-center justify-between">
                  <div className="ml-3">
                    <p className="text-sm font-medium text-gray-900">Revenue</p>
                    <p className="text-lg font-semibold text-gray-900">${stats.totalRevenue}</p>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div className="bg-white overflow-hidden shadow rounded-lg">
            <div className="p-5">
              <div className="flex items-center">
                <div className="flex-shrink-0 bg-blue-500 rounded-md p-3">
                  <svg className="h-6 w-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l3.976-2.888a1 1 0 00.363-1.118l-1.518-4.674z" />
                  </svg>
                </div>
                <div className="ml-5 w-0 flex items-center justify-between">
                  <div className="ml-3">
                    <p className="text-sm font-medium text-gray-900">Avg Rating</p>
                    <p className="text-lg font-semibold text-gray-900">{stats.avgRating.toFixed(1)}</p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Recent Courses */}
        <div className="bg-white shadow overflow-hidden sm:rounded-lg mb-8">
          <div className="px-4 py-5 sm:p-6">
            <div className="flex items-center justify-between">
              <h3 className="text-lg leading-6 font-medium text-gray-900">Your Courses</h3>
              <Link to="/teacher/courses" className="text-sm font-medium text-blue-600 hover:text-blue-500">
                Manage courses →
              </Link>
            </div>
            <div className="mt-6">
              {courses.length === 0 ? (
                <div className="text-center py-12">
                  <svg className="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h2a2 2 0 002-2V7a2 2 0 00-2-2z" />
                  </svg>
                  <h3 className="mt-2 text-sm font-medium text-gray-900">No courses created</h3>
                  <p className="mt-1 text-sm text-gray-500">
                    Get started by creating your first course.
                  </p>
                  <div className="mt-6">
                    <Link to="/teacher/create-course" className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-blue-600 hover:bg-blue-700">
                      Create Course
                    </Link>
                  </div>
                </div>
              ) : (
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
                  {courses.slice(0, 6).map((course) => (
                    <div key={course.id} className="border border-gray-200 rounded-lg p-4 hover:shadow-md transition-shadow">
                      <Link to={`/courses/${course.id}`}>
                        <div className="flex-shrink-0">
                          <img className="h-48 w-full object-cover rounded-lg" src={course.thumbnail_url || '/placeholder-course.jpg'} alt={course.title} />
                        </div>
                        <div className="flex-1 p-4">
                          <h4 className="text-lg font-medium text-gray-900">{course.title}</h4>
                          <p className="mt-1 text-sm text-gray-500 line-clamp-2">{course.short_description}</p>
                          <div className="mt-2 flex items-center">
                            <span className="text-sm font-medium text-blue-600">{course.level}</span>
                            <span className="mx-2 text-sm text-gray-500">•</span>
                            <span className="text-sm font-medium text-gray-900">{course.enrollment_count} students</span>
                          </div>
                          <div className="mt-3 flex items-center justify-between">
                            <span className="text-2xl font-semibold text-gray-900">${course.price}</span>
                            <span className="text-sm text-gray-500">⭐ {course.rating_average.toFixed(1)}</span>
                          </div>
                        </div>
                      </Link>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Recent Students */}
        <div className="bg-white shadow overflow-hidden sm:rounded-lg">
          <div className="px-4 py-5 sm:p-6">
            <div className="flex items-center justify-between">
              <h3 className="text-lg leading-6 font-medium text-gray-900">Recent Students</h3>
              <Link to="/teacher/students" className="text-sm font-medium text-blue-600 hover:text-blue-500">
                View all students →
              </Link>
            </div>
            <div className="mt-6">
              {students.length === 0 ? (
                <div className="text-center py-12">
                  <svg className="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
                  </svg>
                  <h3 className="mt-2 text-sm font-medium text-gray-900">No students enrolled</h3>
                  <p className="mt-1 text-sm text-gray-500">
                    Students will appear here once they enroll in your courses.
                  </p>
                </div>
              ) : (
                <div className="overflow-x-auto">
                  <table className="min-w-full divide-y divide-gray-200">
                    <thead className="bg-gray-50">
                      <tr>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Name</th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Email</th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Enrolled</th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Progress</th>
                      </tr>
                    </thead>
                    <tbody className="bg-white divide-y divide-gray-200">
                      {students.slice(0, 5).map((student) => (
                        <tr key={student.id}>
                          <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                            {student.first_name} {student.last_name}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                            {student.email}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                            {new Date(student.enrolled_at).toLocaleDateString()}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap">
                            <div className="flex items-center">
                              <div className="flex-1 bg-gray-200 rounded-full h-2 mr-2">
                                <div
                                  className="bg-blue-600 h-2 rounded-full"
                                  style={{ width: `${student.progress_percentage}%` }}
                                ></div>
                              </div>
                              <span className="text-sm text-gray-900">{student.progress_percentage}%</span>
                            </div>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default TeacherDashboard;
