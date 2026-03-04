import React, { useState, useEffect, useCallback } from 'react';
import { useTranslation } from 'react-i18next';
import { Search, MoreVertical, UserX, Shield, Mail, Loader2, RefreshCw } from 'lucide-react';
import api from '../../services/api';
import toast from 'react-hot-toast';

export default function AdminUsers() {
  const { t } = useTranslation();
  const [users, setUsers] = useState([]);
  const [total, setTotal] = useState(0);
  const [search, setSearch] = useState('');
  const [roleFilter, setRoleFilter] = useState('all');
  const [openMenu, setOpenMenu] = useState(null);
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState(null);
  const [debouncedSearch, setDebouncedSearch] = useState('');

  useEffect(() => {
    const t = setTimeout(() => setDebouncedSearch(search), 400);
    return () => clearTimeout(t);
  }, [search]);

  const fetchUsers = useCallback(async () => {
    setLoading(true);
    try {
      const params = { limit: 50 };
      if (debouncedSearch) params.search = debouncedSearch;
      if (roleFilter !== 'all') params.role = roleFilter;
      const res = await api.get('/admin/users', { params });
      setUsers(res.data.users || []);
      setTotal(res.data.total || 0);
    } catch {
      toast.error('Failed to load users');
    } finally {
      setLoading(false);
    }
  }, [debouncedSearch, roleFilter]);

  useEffect(() => { fetchUsers(); }, [fetchUsers]);

  const handleAction = async (userId, action, user) => {
    setOpenMenu(null);
    setActionLoading(userId);
    try {
      if (action === 'toggleAdmin') {
        const newRole = user.role === 'admin' ? 'student' : 'admin';
        await api.patch(`/admin/users/${userId}/role`, { role: newRole });
        setUsers((prev) => prev.map((u) => u.id === userId ? { ...u, role: newRole } : u));
        toast.success(`User role updated to ${newRole}`);
      } else if (action === 'toggleBan') {
        const newStatus = user.is_active ? false : true;
        await api.patch(`/admin/users/${userId}/status`, { isActive: newStatus });
        setUsers((prev) => prev.map((u) => u.id === userId ? { ...u, is_active: newStatus } : u));
        toast.success(newStatus ? 'User unbanned' : 'User banned');
      } else if (action === 'sendEmail') {
        toast.success(`Email feature: ${user.email}`);
      }
    } catch {
      toast.error('Action failed');
    } finally {
      setActionLoading(null);
    }
  };

  return (
    <div className="space-y-6 animate-slide-up">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">{t('admin.userManagement')}</h1>
          <p className="text-slate-400 mt-1">{total} total users</p>
        </div>
        <button onClick={fetchUsers} className="btn-secondary text-sm flex items-center gap-2">
          <RefreshCw className="w-4 h-4" />
          Refresh
        </button>
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
        {loading ? (
          <div className="flex items-center justify-center py-16">
            <Loader2 className="w-8 h-8 text-primary-400 animate-spin" />
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b border-slate-700">
                  <th className="text-left p-4 text-xs font-semibold text-slate-400 uppercase tracking-wider">User</th>
                  <th className="text-left p-4 text-xs font-semibold text-slate-400 uppercase tracking-wider">Role</th>
                  <th className="text-left p-4 text-xs font-semibold text-slate-400 uppercase tracking-wider">Status</th>
                  <th className="text-left p-4 text-xs font-semibold text-slate-400 uppercase tracking-wider">Joined</th>
                  <th className="p-4"></th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-700/50">
                {users.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="text-center py-10 text-slate-400">No users found</td>
                  </tr>
                ) : users.map((user) => (
                  <tr key={user.id} className="hover:bg-slate-800/30 transition-colors">
                    <td className="p-4">
                      <div className="flex items-center gap-3">
                        <div className="w-9 h-9 rounded-full bg-gradient-to-br from-primary-500 to-accent-500 flex items-center justify-center text-white text-sm font-bold flex-shrink-0">
                          {(user.first_name || user.email || 'U')[0].toUpperCase()}
                        </div>
                        <div>
                          <p className="text-sm font-medium text-white">{user.first_name} {user.last_name}</p>
                          <p className="text-xs text-slate-400">{user.email}</p>
                        </div>
                      </div>
                    </td>
                    <td className="p-4">
                      <span className={`badge text-xs ${
                        user.role === 'admin' || user.role === 'super_admin' ? 'badge-red' :
                        user.role === 'instructor' ? 'badge-purple' : 'badge-blue'
                      }`}>
                        {user.role}
                      </span>
                    </td>
                    <td className="p-4">
                      <span className={`badge text-xs ${user.is_active ? 'badge-green' : 'badge-red'}`}>
                        {user.is_active ? 'active' : 'banned'}
                      </span>
                    </td>
                    <td className="p-4 text-sm text-slate-400">
                      {user.created_at ? new Date(user.created_at).toLocaleDateString() : '—'}
                    </td>
                    <td className="p-4">
                      <div className="relative">
                        <button
                          onClick={() => setOpenMenu(openMenu === user.id ? null : user.id)}
                          disabled={actionLoading === user.id}
                          className="p-1.5 rounded-lg hover:bg-slate-700 text-slate-400 hover:text-white transition-colors"
                        >
                          {actionLoading === user.id
                            ? <Loader2 className="w-4 h-4 animate-spin" />
                            : <MoreVertical className="w-4 h-4" />}
                        </button>
                        {openMenu === user.id && (
                          <div className="absolute right-0 mt-1 w-44 bg-slate-800 border border-slate-700 rounded-xl shadow-xl z-10 overflow-hidden">
                            {[
                              { icon: Mail, label: 'Send Email', action: 'sendEmail' },
                              { icon: Shield, label: user.role === 'admin' ? 'Remove Admin' : 'Make Admin', action: 'toggleAdmin' },
                              { icon: UserX, label: user.is_active ? 'Ban User' : 'Unban User', action: 'toggleBan', danger: true },
                            ].map(({ icon: Icon, label, action, danger }) => (
                              <button
                                key={label}
                                onClick={() => handleAction(user.id, action, user)}
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
        )}
      </div>
    </div>
  );
}
