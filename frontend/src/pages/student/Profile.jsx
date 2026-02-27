import React, { useState, useEffect } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { useTranslation } from 'react-i18next';
import { User, Mail, Globe, Camera, Save, Loader2 } from 'lucide-react';
import api from '../../services/api';
import toast from 'react-hot-toast';
import { fetchCurrentUser } from '../../store/slices/authSlice';

export default function ProfilePage() {
  const { t } = useTranslation();
  const dispatch = useDispatch();
  const { user } = useSelector((state) => state.auth);
  const [form, setForm] = useState({
    firstName: '',
    lastName: '',
    bio: '',
    languagePreference: 'en',
  });
  const [saving, setSaving] = useState(false);
  const [passwordForm, setPasswordForm] = useState({ currentPassword: '', newPassword: '', confirmPassword: '' });
  const [changingPassword, setChangingPassword] = useState(false);

  useEffect(() => {
    if (user) {
      setForm({
        firstName: user.firstName || '',
        lastName: user.lastName || '',
        bio: user.bio || '',
        languagePreference: user.languagePreference || 'en',
      });
    }
  }, [user]);

  const handleSaveProfile = async (e) => {
    e.preventDefault();
    setSaving(true);
    try {
      await api.patch('/users/profile', form);
      dispatch(fetchCurrentUser());
      toast.success('Profile updated successfully');
    } catch {
      toast.error('Failed to update profile');
    } finally {
      setSaving(false);
    }
  };

  const handleChangePassword = async (e) => {
    e.preventDefault();
    if (passwordForm.newPassword !== passwordForm.confirmPassword) {
      toast.error('Passwords do not match');
      return;
    }
    if (passwordForm.newPassword.length < 8) {
      toast.error('Password must be at least 8 characters');
      return;
    }
    setChangingPassword(true);
    try {
      await api.patch('/users/password', {
        currentPassword: passwordForm.currentPassword,
        newPassword: passwordForm.newPassword,
      });
      toast.success('Password changed successfully');
      setPasswordForm({ currentPassword: '', newPassword: '', confirmPassword: '' });
    } catch (err) {
      toast.error(err.response?.data?.error?.message || 'Failed to change password');
    } finally {
      setChangingPassword(false);
    }
  };

  return (
    <div className="space-y-6 animate-slide-up max-w-2xl">
      <div>
        <h1 className="text-2xl font-bold text-white">{t('common.profile')}</h1>
        <p className="text-slate-400 mt-1">Manage your account information</p>
      </div>

      <div className="card">
        <div className="flex items-center gap-5 mb-6 pb-6 border-b border-slate-700">
          <div className="relative">
            <div className="w-20 h-20 rounded-full bg-gradient-to-br from-primary-500 to-accent-500 flex items-center justify-center text-white text-2xl font-bold">
              {user?.firstName?.[0]?.toUpperCase() || 'U'}
            </div>
            <button className="absolute bottom-0 right-0 w-7 h-7 bg-slate-700 border border-slate-600 rounded-full flex items-center justify-center hover:bg-slate-600 transition-colors">
              <Camera className="w-3.5 h-3.5 text-slate-300" />
            </button>
          </div>
          <div>
            <p className="text-lg font-semibold text-white">{user?.firstName} {user?.lastName}</p>
            <p className="text-sm text-slate-400">{user?.email}</p>
            <span className={`badge text-xs mt-1 inline-block ${
              user?.role === 'admin' ? 'badge-red' : user?.role === 'instructor' ? 'badge-purple' : 'badge-blue'
            }`}>{user?.role}</span>
          </div>
        </div>

        <form onSubmit={handleSaveProfile} className="space-y-4">
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-slate-300 mb-1.5">
                <User className="w-4 h-4 inline mr-1" />{t('auth.firstName')}
              </label>
              <input value={form.firstName} onChange={(e) => setForm({ ...form, firstName: e.target.value })}
                className="input-field" />
            </div>
            <div>
              <label className="block text-sm font-medium text-slate-300 mb-1.5">{t('auth.lastName')}</label>
              <input value={form.lastName} onChange={(e) => setForm({ ...form, lastName: e.target.value })}
                className="input-field" />
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-slate-300 mb-1.5">
              <Mail className="w-4 h-4 inline mr-1" />Email
            </label>
            <input value={user?.email || ''} disabled className="input-field opacity-50 cursor-not-allowed" />
          </div>

          <div>
            <label className="block text-sm font-medium text-slate-300 mb-1.5">Bio</label>
            <textarea value={form.bio} onChange={(e) => setForm({ ...form, bio: e.target.value })}
              placeholder="Tell us about yourself..."
              className="input-field h-24 resize-none" />
          </div>

          <div>
            <label className="block text-sm font-medium text-slate-300 mb-1.5">
              <Globe className="w-4 h-4 inline mr-1" />Language Preference
            </label>
            <select value={form.languagePreference}
              onChange={(e) => setForm({ ...form, languagePreference: e.target.value })}
              className="input-field w-48">
              <option value="en">English</option>
              <option value="mn">Монгол (Mongolian)</option>
            </select>
          </div>

          <button type="submit" disabled={saving} className="btn-primary flex items-center gap-2">
            {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
            Save Profile
          </button>
        </form>
      </div>

      <div className="card">
        <h2 className="text-lg font-semibold text-white mb-5">Change Password</h2>
        <form onSubmit={handleChangePassword} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-slate-300 mb-1.5">Current Password</label>
            <input type="password" value={passwordForm.currentPassword}
              onChange={(e) => setPasswordForm({ ...passwordForm, currentPassword: e.target.value })}
              className="input-field" required />
          </div>
          <div>
            <label className="block text-sm font-medium text-slate-300 mb-1.5">New Password</label>
            <input type="password" value={passwordForm.newPassword}
              onChange={(e) => setPasswordForm({ ...passwordForm, newPassword: e.target.value })}
              className="input-field" required minLength={8} />
          </div>
          <div>
            <label className="block text-sm font-medium text-slate-300 mb-1.5">Confirm New Password</label>
            <input type="password" value={passwordForm.confirmPassword}
              onChange={(e) => setPasswordForm({ ...passwordForm, confirmPassword: e.target.value })}
              className="input-field" required />
          </div>
          <button type="submit" disabled={changingPassword} className="btn-secondary flex items-center gap-2">
            {changingPassword ? <Loader2 className="w-4 h-4 animate-spin" /> : null}
            Change Password
          </button>
        </form>
      </div>
    </div>
  );
}
