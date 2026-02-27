import React, { useState, useEffect, useCallback } from 'react';
import { useTranslation } from 'react-i18next';
import { Search, Plus, Edit, Trash2, Eye, Loader2, RefreshCw, X, Save } from 'lucide-react';
import api from '../../services/api';
import toast from 'react-hot-toast';

function CourseModal({ course, onClose, onSave }) {
  const [form, setForm] = useState({
    title: course?.title || '',
    description: course?.description || '',
    level: course?.level || 'beginner',
    price: course?.price || 0,
    category_id: course?.category_id || '',
  });
  const [saving, setSaving] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSaving(true);
    try {
      if (course) {
        await api.put(`/courses/${course.id}`, form);
        toast.success('Course updated');
      } else {
        await api.post('/courses', form);
        toast.success('Course created');
      }
      onSave();
      onClose();
    } catch (err) {
      toast.error(err.response?.data?.error?.message || 'Failed to save course');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-50 p-4">
      <div className="bg-slate-800 border border-slate-700 rounded-2xl w-full max-w-lg">
        <div className="flex items-center justify-between p-5 border-b border-slate-700">
          <h2 className="text-lg font-semibold text-white">{course ? 'Edit Course' : 'Create Course'}</h2>
          <button onClick={onClose} className="p-1.5 rounded-lg hover:bg-slate-700 text-slate-400 hover:text-white">
            <X className="w-5 h-5" />
          </button>
        </div>
        <form onSubmit={handleSubmit} className="p-5 space-y-4">
          <div>
            <label className="block text-sm font-medium text-slate-300 mb-1.5">Title *</label>
            <input value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })}
              required className="input-field" placeholder="Course title" />
          </div>
          <div>
            <label className="block text-sm font-medium text-slate-300 mb-1.5">Description</label>
            <textarea value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })}
              className="input-field h-24 resize-none" placeholder="Course description" />
          </div>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-slate-300 mb-1.5">Level</label>
              <select value={form.level} onChange={(e) => setForm({ ...form, level: e.target.value })} className="input-field">
                <option value="beginner">Beginner</option>
                <option value="intermediate">Intermediate</option>
                <option value="advanced">Advanced</option>
              </select>
            </div>
            <div>
              <label className="block text-sm font-medium text-slate-300 mb-1.5">Price ($)</label>
              <input type="number" min="0" step="0.01" value={form.price}
                onChange={(e) => setForm({ ...form, price: parseFloat(e.target.value) || 0 })}
                className="input-field" />
            </div>
          </div>
          <div className="flex gap-3 pt-2">
            <button type="button" onClick={onClose} className="btn-secondary flex-1">Cancel</button>
            <button type="submit" disabled={saving} className="btn-primary flex-1 flex items-center justify-center gap-2">
              {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
              {course ? 'Update' : 'Create'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

export default function AdminCourses() {
  const { t } = useTranslation();
  const [courses, setCourses] = useState([]);
  const [total, setTotal] = useState(0);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [modalCourse, setModalCourse] = useState(undefined);
  const [deletingId, setDeletingId] = useState(null);

  const fetchCourses = useCallback(async () => {
    setLoading(true);
    try {
      const params = { limit: 50, admin: true };
      if (search) params.search = search;
      const res = await api.get('/courses', { params });
      setCourses(res.data.courses || []);
      setTotal(res.data.total || 0);
    } catch {
      toast.error('Failed to load courses');
    } finally {
      setLoading(false);
    }
  }, [search]);

  useEffect(() => {
    const t = setTimeout(fetchCourses, 400);
    return () => clearTimeout(t);
  }, [fetchCourses]);

  const handleDelete = async (courseId) => {
    if (!window.confirm('Delete this course? This cannot be undone.')) return;
    setDeletingId(courseId);
    try {
      await api.delete(`/courses/${courseId}`);
      setCourses((prev) => prev.filter((c) => c.id !== courseId));
      toast.success('Course deleted');
    } catch {
      toast.error('Failed to delete course');
    } finally {
      setDeletingId(null);
    }
  };

  const handlePublish = async (course) => {
    try {
      await api.patch(`/courses/${course.id}/publish`, { published: !course.is_published });
      setCourses((prev) => prev.map((c) => c.id === course.id ? { ...c, is_published: !c.is_published } : c));
      toast.success(course.is_published ? 'Course unpublished' : 'Course published');
    } catch {
      toast.error('Failed to update course status');
    }
  };

  return (
    <div className="space-y-6 animate-slide-up">
      {modalCourse !== undefined && (
        <CourseModal
          course={modalCourse || null}
          onClose={() => setModalCourse(undefined)}
          onSave={fetchCourses}
        />
      )}

      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">{t('admin.courseManagement')}</h1>
          <p className="text-slate-400 mt-1">{total} total courses</p>
        </div>
        <div className="flex gap-2">
          <button onClick={fetchCourses} className="btn-secondary text-sm flex items-center gap-2">
            <RefreshCw className="w-4 h-4" />
          </button>
          <button onClick={() => setModalCourse(null)} className="btn-primary text-sm flex items-center gap-2">
            <Plus className="w-4 h-4" />
            {t('admin.createCourse')}
          </button>
        </div>
      </div>

      <div className="relative">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
        <input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Search courses..." className="input-field pl-10" />
      </div>

      <div className="card overflow-hidden p-0">
        {loading ? (
          <div className="flex items-center justify-center py-16">
            <Loader2 className="w-8 h-8 text-primary-400 animate-spin" />
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b border-slate-700">
                  {['Course', 'Instructor', 'Level', 'Price', 'Students', 'Status', 'Actions'].map((h) => (
                    <th key={h} className="text-left p-4 text-xs font-semibold text-slate-400 uppercase tracking-wider">{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-700/50">
                {courses.length === 0 ? (
                  <tr>
                    <td colSpan={7} className="text-center py-10 text-slate-400">No courses found</td>
                  </tr>
                ) : courses.map((course) => (
                  <tr key={course.id} className="hover:bg-slate-800/30 transition-colors">
                    <td className="p-4">
                      <p className="text-sm font-medium text-white max-w-xs truncate">{course.title}</p>
                    </td>
                    <td className="p-4 text-sm text-slate-400">{course.instructor_name || '—'}</td>
                    <td className="p-4">
                      <span className="badge-purple text-xs capitalize">{course.level}</span>
                    </td>
                    <td className="p-4 text-sm text-slate-300">
                      {parseFloat(course.price || 0) === 0
                        ? <span className="text-green-400">Free</span>
                        : `$${parseFloat(course.price).toFixed(2)}`}
                    </td>
                    <td className="p-4 text-sm text-slate-300">{(course.total_enrollments || 0).toLocaleString()}</td>
                    <td className="p-4">
                      <span className={`badge text-xs ${course.is_published ? 'badge-green' : 'badge-yellow'}`}>
                        {course.is_published ? 'published' : 'draft'}
                      </span>
                    </td>
                    <td className="p-4">
                      <div className="flex items-center gap-1">
                        <button
                          onClick={() => handlePublish(course)}
                          title={course.is_published ? 'Unpublish' : 'Publish'}
                          className="p-1.5 rounded-lg hover:bg-slate-700 text-slate-400 hover:text-white transition-colors text-xs"
                        >
                          {course.is_published ? '⏸' : '▶'}
                        </button>
                        <button
                          onClick={() => setModalCourse(course)}
                          className="p-1.5 rounded-lg hover:bg-slate-700 text-slate-400 hover:text-white transition-colors"
                        >
                          <Edit className="w-4 h-4" />
                        </button>
                        <button
                          onClick={() => handleDelete(course.id)}
                          disabled={deletingId === course.id}
                          className="p-1.5 rounded-lg hover:bg-red-500/10 text-slate-400 hover:text-red-400 transition-colors"
                        >
                          {deletingId === course.id
                            ? <Loader2 className="w-4 h-4 animate-spin" />
                            : <Trash2 className="w-4 h-4" />}
                        </button>
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
  );
}
