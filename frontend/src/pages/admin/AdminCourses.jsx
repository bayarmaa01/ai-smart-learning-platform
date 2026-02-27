import React, { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Search, Plus, Edit, Trash2, Eye, ToggleLeft, ToggleRight } from 'lucide-react';

const mockCourses = [
  { id: '1', title: 'Machine Learning A-Z', instructor: 'Dr. Sarah Chen', students: 45230, revenue: 0, status: 'published', category: 'AI/ML' },
  { id: '2', title: 'React & Node.js Full Stack', instructor: 'John Smith', students: 38100, revenue: 1905000, status: 'published', category: 'Programming' },
  { id: '3', title: 'AWS Solutions Architect', instructor: 'Mike Johnson', students: 22400, revenue: 1791200, status: 'published', category: 'DevOps' },
  { id: '4', title: 'Python for Data Science', instructor: 'Emma Wilson', students: 61200, revenue: 0, status: 'published', category: 'Data Science' },
  { id: '5', title: 'Kubernetes Advanced', instructor: 'Alex Turner', students: 0, revenue: 0, status: 'draft', category: 'DevOps' },
];

export default function AdminCourses() {
  const { t } = useTranslation();
  const [search, setSearch] = useState('');

  const filtered = mockCourses.filter((c) =>
    c.title.toLowerCase().includes(search.toLowerCase()) ||
    c.instructor.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div className="space-y-6 animate-slide-up">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">{t('admin.courseManagement')}</h1>
          <p className="text-slate-400 mt-1">{mockCourses.length} total courses</p>
        </div>
        <button className="btn-primary text-sm flex items-center gap-2">
          <Plus className="w-4 h-4" />
          {t('admin.createCourse')}
        </button>
      </div>

      <div className="relative">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
        <input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Search courses..." className="input-field pl-10" />
      </div>

      <div className="card overflow-hidden p-0">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="border-b border-slate-700">
                {['Course', 'Instructor', 'Category', 'Students', 'Revenue', 'Status', 'Actions'].map((h) => (
                  <th key={h} className="text-left p-4 text-xs font-semibold text-slate-400 uppercase tracking-wider">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-700/50">
              {filtered.map((course) => (
                <tr key={course.id} className="hover:bg-slate-800/30 transition-colors">
                  <td className="p-4">
                    <p className="text-sm font-medium text-white max-w-xs truncate">{course.title}</p>
                  </td>
                  <td className="p-4 text-sm text-slate-400">{course.instructor}</td>
                  <td className="p-4"><span className="badge-purple text-xs">{course.category}</span></td>
                  <td className="p-4 text-sm text-slate-300">{course.students.toLocaleString()}</td>
                  <td className="p-4 text-sm text-slate-300">
                    {course.revenue === 0 ? <span className="text-green-400">Free</span> : `$${(course.revenue / 100).toLocaleString()}`}
                  </td>
                  <td className="p-4">
                    <span className={`badge text-xs ${course.status === 'published' ? 'badge-green' : 'badge-yellow'}`}>
                      {course.status}
                    </span>
                  </td>
                  <td className="p-4">
                    <div className="flex items-center gap-1">
                      <button className="p-1.5 rounded-lg hover:bg-slate-700 text-slate-400 hover:text-white transition-colors">
                        <Eye className="w-4 h-4" />
                      </button>
                      <button className="p-1.5 rounded-lg hover:bg-slate-700 text-slate-400 hover:text-white transition-colors">
                        <Edit className="w-4 h-4" />
                      </button>
                      <button className="p-1.5 rounded-lg hover:bg-red-500/10 text-slate-400 hover:text-red-400 transition-colors">
                        <Trash2 className="w-4 h-4" />
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
