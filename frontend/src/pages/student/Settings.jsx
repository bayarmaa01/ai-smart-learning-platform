import React, { useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { useTranslation } from 'react-i18next';
import { Bell, Moon, Sun, Globe, Shield, Loader2, Save } from 'lucide-react';
import { setTheme } from '../../store/slices/uiSlice';
import LanguageSwitcher from '../../components/common/LanguageSwitcher';
import toast from 'react-hot-toast';
import api from '../../services/api';

export default function SettingsPage() {
  const { t, i18n } = useTranslation();
  const dispatch = useDispatch();
  const { theme } = useSelector((state) => state.ui);
  const [notifications, setNotifications] = useState({
    emailCourseUpdates: true,
    emailNewMessages: true,
    emailWeeklyDigest: false,
    pushNotifications: true,
  });
  const [saving, setSaving] = useState(false);

  const handleSaveNotifications = async () => {
    setSaving(true);
    try {
      await api.patch('/users/notification-preferences', notifications);
      toast.success('Notification preferences saved');
    } catch {
      toast.error('Failed to save preferences');
    } finally {
      setSaving(false);
    }
  };

  const Toggle = ({ name, label, description, state, setState }) => (
    <div className="flex items-center justify-between p-4 bg-slate-800/30 rounded-xl">
      <div>
        <p className="text-sm font-medium text-white">{label}</p>
        {description && <p className="text-xs text-slate-400 mt-0.5">{description}</p>}
      </div>
      <button
        onClick={() => setState({ ...state, [name]: !state[name] })}
        className={`relative w-11 h-6 rounded-full transition-colors duration-200 ${
          state[name] ? 'bg-primary-600' : 'bg-slate-600'
        }`}
      >
        <div className={`absolute top-1 w-4 h-4 bg-white rounded-full shadow transition-transform duration-200 ${
          state[name] ? 'translate-x-6' : 'translate-x-1'
        }`} />
      </button>
    </div>
  );

  return (
    <div className="space-y-6 animate-slide-up max-w-2xl">
      <div>
        <h1 className="text-2xl font-bold text-white">{t('common.settings')}</h1>
        <p className="text-slate-400 mt-1">Customize your experience</p>
      </div>

      <div className="card">
        <div className="flex items-center gap-3 mb-5 pb-4 border-b border-slate-700">
          <div className="w-9 h-9 bg-primary-600/20 rounded-xl flex items-center justify-center">
            <Globe className="w-5 h-5 text-primary-400" />
          </div>
          <h2 className="text-lg font-semibold text-white">Language</h2>
        </div>
        <div className="flex items-center gap-4">
          <p className="text-sm text-slate-300">Interface Language:</p>
          <LanguageSwitcher />
        </div>
        <p className="text-xs text-slate-500 mt-3">
          Current: {i18n.language === 'mn' ? 'Монгол (Mongolian)' : 'English'}
        </p>
      </div>

      <div className="card">
        <div className="flex items-center gap-3 mb-5 pb-4 border-b border-slate-700">
          <div className="w-9 h-9 bg-primary-600/20 rounded-xl flex items-center justify-center">
            {theme === 'dark' ? <Moon className="w-5 h-5 text-primary-400" /> : <Sun className="w-5 h-5 text-primary-400" />}
          </div>
          <h2 className="text-lg font-semibold text-white">Appearance</h2>
        </div>
        <div className="flex gap-3">
          {['dark', 'light'].map((t) => (
            <button
              key={t}
              onClick={() => dispatch(setTheme(t))}
              className={`flex items-center gap-2 px-4 py-2.5 rounded-xl border text-sm font-medium transition-all ${
                theme === t
                  ? 'border-primary-500 bg-primary-600/20 text-primary-300'
                  : 'border-slate-600 text-slate-400 hover:border-slate-500'
              }`}
            >
              {t === 'dark' ? <Moon className="w-4 h-4" /> : <Sun className="w-4 h-4" />}
              {t.charAt(0).toUpperCase() + t.slice(1)} Mode
            </button>
          ))}
        </div>
      </div>

      <div className="card">
        <div className="flex items-center gap-3 mb-5 pb-4 border-b border-slate-700">
          <div className="w-9 h-9 bg-primary-600/20 rounded-xl flex items-center justify-center">
            <Bell className="w-5 h-5 text-primary-400" />
          </div>
          <h2 className="text-lg font-semibold text-white">Notifications</h2>
        </div>
        <div className="space-y-3">
          <Toggle name="emailCourseUpdates" label="Course Updates"
            description="Get notified when your enrolled courses have new content"
            state={notifications} setState={setNotifications} />
          <Toggle name="emailNewMessages" label="New Messages"
            description="Email notifications for new messages and replies"
            state={notifications} setState={setNotifications} />
          <Toggle name="emailWeeklyDigest" label="Weekly Digest"
            description="Weekly summary of your learning progress"
            state={notifications} setState={setNotifications} />
          <Toggle name="pushNotifications" label="Push Notifications"
            description="Browser push notifications for real-time updates"
            state={notifications} setState={setNotifications} />
        </div>
        <button onClick={handleSaveNotifications} disabled={saving}
          className="btn-primary flex items-center gap-2 mt-5">
          {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
          Save Preferences
        </button>
      </div>

      <div className="card">
        <div className="flex items-center gap-3 mb-5 pb-4 border-b border-slate-700">
          <div className="w-9 h-9 bg-red-600/20 rounded-xl flex items-center justify-center">
            <Shield className="w-5 h-5 text-red-400" />
          </div>
          <h2 className="text-lg font-semibold text-white">Danger Zone</h2>
        </div>
        <div className="p-4 border border-red-500/20 rounded-xl bg-red-500/5">
          <p className="text-sm font-medium text-white mb-1">Delete Account</p>
          <p className="text-xs text-slate-400 mb-3">
            Permanently delete your account and all associated data. This action cannot be undone.
          </p>
          <button
            onClick={() => toast.error('Please contact support to delete your account')}
            className="px-4 py-2 text-sm font-medium text-red-400 border border-red-500/30 rounded-lg hover:bg-red-500/10 transition-colors"
          >
            Delete My Account
          </button>
        </div>
      </div>
    </div>
  );
}
