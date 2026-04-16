import React, { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { toast } from 'react-hot-toast';
import api from '../services/api';

const CourseDetail = ({ user }) => {
  const { id } = useParams();
  const [course, setCourse] = useState(null);
  const [lessons, setLessons] = useState([]);
  const [enrolled, setEnrolled] = useState(false);
  const [loading, setLoading] = useState(true);
  const [enrolling, setEnrolling] = useState(false);

  useEffect(() => {
    const fetchCourseData = async () => {
      try {
        setLoading(true);
        
        // Fetch course details
        const courseResponse = await api.get(`/courses/${id}`);
        setCourse(courseResponse.data.course);

        // Fetch lessons
        const lessonsResponse = await api.get(`/courses/${id}/lessons`);
        setLessons(lessonsResponse.data.lessons || []);

        // Check enrollment status
        try {
          const enrollmentResponse = await api.get(`/enrollments/course/${id}`);
          setEnrolled(!!enrollmentResponse.data.enrollment);
        } catch (error) {
          // Not enrolled
          setEnrolled(false);
        }
      } catch (error) {
        console.error('Failed to fetch course data:', error);
        toast.error('Failed to load course');
      } finally {
        setLoading(false);
      }
    };

    fetchCourseData();
  }, [id]);

  const handleEnroll = async () => {
    setEnrolling(true);
    try {
      const response = await api.post(`/enrollments`, { courseId: id });
      
      if (response.data.success) {
        setEnrolled(true);
        toast.success('Successfully enrolled in course!');
      } else {
        toast.error(response.data.error?.message || 'Enrollment failed');
      }
    } catch (error) {
      toast.error(error.response?.data?.error?.message || 'Enrollment failed');
    } finally {
      setEnrolling(false);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  if (!course) {
    return (
      <div className="min-h-screen bg-gray-50">
        <div className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
          <div className="text-center">
            <h1 className="text-3xl font-bold text-gray-900">Course Not Found</h1>
            <p className="mt-2 text-gray-600">The course you're looking for doesn't exist.</p>
            <Link to="/courses" className="mt-4 inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700">
              Back to Courses
            </Link>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        {/* Course Header */}
        <div className="bg-white shadow rounded-lg overflow-hidden mb-8">
          <div className="relative h-64">
            <img
              className="w-full h-full object-cover"
              src={course.thumbnail_url || '/placeholder-course.jpg'}
              alt={course.title}
            />
            <div className="absolute inset-0 bg-black bg-opacity-40 flex items-center justify-center">
              <div className="text-center text-white">
                <h1 className="text-4xl font-bold mb-2">{course.title}</h1>
                <p className="text-xl">{course.short_description}</p>
              </div>
            </div>
          </div>
          
          <div className="p-6">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center space-x-4">
                <span className="px-3 py-1 bg-blue-100 text-blue-800 text-sm font-medium rounded-full capitalize">
                  {course.level}
                </span>
                <span className="text-gray-600">{course.duration_hours} hours</span>
                <span className="text-gray-600">{lessons.length} lessons</span>
              </div>
              
              <div className="flex items-center">
                <svg className="h-5 w-5 text-yellow-400" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                </svg>
                <span className="ml-1 text-gray-600">
                  {course.rating_average.toFixed(1)} ({course.rating_count} reviews)
                </span>
              </div>
            </div>

            <div className="prose max-w-none mb-6">
              <p className="text-gray-700">{course.description}</p>
            </div>

            <div className="flex items-center justify-between">
              <div>
                <span className="text-3xl font-bold text-gray-900">
                  {course.is_free ? 'Free' : `$${course.price}`}
                </span>
                <span className="ml-2 text-gray-500">{course.enrollment_count} students enrolled</span>
              </div>
              
              {!enrolled ? (
                <button
                  onClick={handleEnroll}
                  disabled={enrolling}
                  className="px-6 py-3 bg-blue-600 text-white font-medium rounded-md hover:bg-blue-700 disabled:opacity-50"
                >
                  {enrolling ? 'Enrolling...' : course.is_free ? 'Enroll for Free' : `Buy Course - $${course.price}`}
                </button>
              ) : (
                <div className="flex items-center text-green-600">
                  <svg className="h-5 w-5 mr-2" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                  </svg>
                  <span className="font-medium">Enrolled</span>
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Course Content */}
        {enrolled && (
          <div className="bg-white shadow rounded-lg p-6 mb-8">
            <h2 className="text-2xl font-bold text-gray-900 mb-4">Course Content</h2>
            <div className="space-y-4">
              {lessons.map((lesson, index) => (
                <div key={lesson.id} className="border border-gray-200 rounded-lg p-4 hover:bg-gray-50">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center">
                      <div className="flex-shrink-0 w-8 h-8 bg-blue-100 rounded-full flex items-center justify-center">
                        <span className="text-blue-600 font-medium">{index + 1}</span>
                      </div>
                      <div className="ml-4">
                        <h3 className="text-lg font-medium text-gray-900">{lesson.title}</h3>
                        <p className="text-sm text-gray-500">{lesson.duration_minutes} minutes</p>
                      </div>
                    </div>
                    <Link
                      to={`/courses/${id}/lessons/${lesson.id}`}
                      className="px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-md hover:bg-blue-700"
                    >
                      Start Lesson
                    </Link>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Course Info */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div className="bg-white shadow rounded-lg p-6">
            <h3 className="text-lg font-medium text-gray-900 mb-2">Instructor</h3>
            <div className="flex items-center">
              <div className="flex-shrink-0 h-10 w-10 bg-gray-300 rounded-full"></div>
              <div className="ml-3">
                <p className="text-sm font-medium text-gray-900">{course.instructor?.first_name} {course.instructor?.last_name}</p>
                <p className="text-sm text-gray-500">{course.instructor?.role}</p>
              </div>
            </div>
          </div>

          <div className="bg-white shadow rounded-lg p-6">
            <h3 className="text-lg font-medium text-gray-900 mb-2">Duration</h3>
            <p className="text-2xl font-bold text-gray-900">{course.duration_hours} hours</p>
            <p className="text-sm text-gray-500">Self-paced learning</p>
          </div>

          <div className="bg-white shadow rounded-lg p-6">
            <h3 className="text-lg font-medium text-gray-900 mb-2">Certificate</h3>
            <div className="flex items-center">
              <svg className="h-6 w-6 text-green-500" fill="currentColor" viewBox="0 0 20 20">
                <path d="M9 2a2 2 0 00-2 2v8a2 2 0 002 2h6a2 2 0 002-2V6.414A2 2 0 0016.414 5L14 2.586A2 2 0 0012.586 2H9z" />
                <path d="M3 8a2 2 0 012-2v10h8a2 2 0 01-2 2H5a2 2 0 01-2-2V8z" />
              </svg>
              <span className="ml-2 text-sm text-gray-600">Certificate of completion</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default CourseDetail;
