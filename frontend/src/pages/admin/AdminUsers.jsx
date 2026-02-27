import React, { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Search, Filter, MoreVertical, UserX, Shield, Mail } from 'lucide-react';

const mockUsers = [
  { id: '1', name: 'Bat-Erdene Gantulga', email: 'bat@example.mn', role: 'student', status: 'active', joined: '2024-01-15', courses: 5 },
  { id: '2', name: 'Sarah Johnson', email: 'sarah@example.com', role: 'student', status: 'active', joined: '2024-01-20', courses: 3 },
  { id: '3', name: 'Oyunbaatar Dorj', email: 'oyun@example.mn', role: 'instructor', status: 'active', joined: '2023-11-10', courses: 12 },
  { id: '4', name: 'Mike Chen', email: 'mike@example.com', role: 'admin', status: 'active', joined: '2023-09-05', courses: 0 },
  { id: '5', name: 'Enkhjargal Bold', email: 'enkh@example.mn', role: 'student', status: 'banned', joined: '2024-02-01', courses: 1 },
];

export default function AdminUsers() {
  const { t } = useTranslation();
  const [search, setSearch] = useState('');
  const [roleFilter, setRoleFilter] = useState('all');
  const [openMenu, setOpenMenu] = useState(null);

  const filtered = mockUsers.filter((u) => {
    const matchSearch = u.name.toLowerCase().includes(search.toLowerCase()) || u.email.toLowerCase().includes(search.toLowerCase());
    const matchRole = roleFilter === 'all' || u.role === roleFilter;
    return matchSearch && matchRole;
  });

  return (
    <div className="space-y-6 animate-slide-up">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">{t('admin.userManagement')}</h1>
          <p className="text-slate-400 mt-1">{mockUsers.length} total users</p>
        </div>
        <button className="btn-primary text-sm">+ Invite User</button>
      </div>

      <div className="flex flex-col sm:flex-row gap-4">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search users..."
            className="input-field pl-10"
          />
        </div>
        <select value={roleFilter} onChange={(e) => setRoleFilter(e.target.value)} className="input-field w-full sm:w-40">
          <option value="all">All Roles</option>
          <option value="student">Student</option>
          <option value="instructor">Instructor</option>
          <option value="admin">Admin</option>
        </select>
      </div>

      <div className="card overflow-hidden p-0">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="border-b border-slate-700">
                <th className="text-left p-4 text-xs font-semibold text-slate-400 uppercase tracking-wider">User</th>
                <th className="text-left p-4 text-xs font-semibold text-slate-400 uppercase tracking-wider">Role</th>
                <th className="text-left p-4 text-xs font-semibold text-slate-400 uppercase tracking-wider">Status</th>
                <th className="text-left p-4 text-xs font-semibold text-slate-400 uppercase tracking-wider">Courses</th>
                <th className="text-left p-4 text-xs font-semibold text-slate-400 uppercase tracking-wider">Joined</th>
                <th className="p-4"></th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-700/50">
              {filtered.map((user) => (
                <tr key={user.id} className="hover:bg-slate-800/30 transition-colors">
                  <td className="p-4">
                    <div className="flex items-center gap-3">
                      <div className="w-9 h-9 rounded-full bg-gradient-to-br from-primary-500 to-accent-500 flex items-center justify-center text-white text-sm font-bold flex-shrink-0">
                        {user.name[0]}
                      </div>
                      <div>
                        <p className="text-sm font-medium text-white">{user.name}</p>
                        <p className="text-xs text-slate-400">{user.email}</p>
                      </div>
                    </div>
                  </td>
                  <td className="p-4">
                    <span className={`badge text-xs ${
                      user.role === 'admin' ? 'badge-red' :
                      user.role === 'instructor' ? 'badge-purple' : 'badge-blue'
                    }`}>
                      {user.role}
                    </span>
                  </td>
                  <td className="p-4">
                    <span className={`badge text-xs ${user.status === 'active' ? 'badge-green' : 'badge-red'}`}>
                      {user.status}
                    </span>
                  </td>
                  <td className="p-4 text-sm text-slate-300">{user.courses}</td>
                  <td className="p-4 text-sm text-slate-400">{new Date(user.joined).toLocaleDateString()}</td>
                  <td className="p-4">
                    <div className="relative">
                      <button
                        onClick={() => setOpenMenu(openMenu === user.id ? null : user.id)}
                        className="p-1.5 rounded-lg hover:bg-slate-700 text-slate-400 hover:text-white transition-colors"
                      >
                        <MoreVertical className="w-4 h-4" />
                      </button>
                      {openMenu === user.id && (
                        <div className="absolute right-0 mt-1 w-44 bg-slate-800 border border-slate-700 rounded-xl shadow-xl z-10 overflow-hidden">
                          {[
                            { icon: Mail, label: 'Send Email' },
                            { icon: Shield, label: user.role === 'admin' ? 'Remove Admin' : 'Make Admin' },
                            { icon: UserX, label: user.status === 'banned' ? 'Unban User' : 'Ban User', danger: true },
                          ].map(({ icon: Icon, label, danger }) => (
                            <button
                              key={label}
                              onClick={() => setOpenMenu(null)}
                              className={`w-full flex items-center gap-2 px-3 py-2.5 text-sm transition-colors ${
                                danger ? 'text-red-400 hover:bg-red-500/10' : 'text-slate-300 hover:bg-slate-700'
                              }`}
                            >
                              <Icon className="w-4 h-4" />
                              {label}
                            </button>
                          ))}
                        </div>
                      )}
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
